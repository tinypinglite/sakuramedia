import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:sakuramedia/core/network/paginated_response_dto.dart';
import 'package:sakuramedia/core/network/sse_event_stream_client.dart';
import 'package:sakuramedia/features/configuration/data/dto/download_client_dto.dart';
import 'package:sakuramedia/features/downloads/data/download_task_stream_event_dto.dart';
import 'package:sakuramedia/features/downloads/presentation/download_task_filter_state.dart';
import 'package:sakuramedia/features/downloads/presentation/providers/download_task_center_state.dart';
import 'package:sakuramedia/features/downloads/presentation/providers/downloads_api_provider.dart';
import 'package:sakuramedia/features/shared/presentation/providers/paged_async_notifier.dart';

part 'download_task_center_provider.g.dart';

Duration? noDownloadTaskCenterRetry(int retryCount, Object error) => null;

/// 下载任务中心（Riverpod）：分页拉 `/download-tasks` + SSE 实时进度 + 暂停/恢复/删除。
///
/// 迁移前对应：`DownloadTaskCenterController extends ChangeNotifier`。
///
/// 差异：
/// - 首屏 loading / error 由外层 [AsyncValue] 表达（[AsyncLoading]/[AsyncError]）；
///   retry 走 `ref.invalidateSelf()`。
/// - 筛选切换（[applyFilter]）**不走 [reload]**（那样会 AsyncLoading 让筛选栏消失），
///   而是自定义流程：`state = AsyncData(旧 items + isReloading: true)` → 拉新首页 →
///   写回。开始前调 [invalidateInFlightLoadMore] 让旧 loadMore 作废。
/// - SSE 触发的「首页去抖合并」维持原生流程：独立 fetchPage(1) + 手工 upsert，
///   有 [_minMergeInterval] 限流兜底。
@Riverpod(keepAlive: true, retry: noDownloadTaskCenterRetry)
class DownloadTaskCenter extends _$DownloadTaskCenter
    with PagedAsyncNotifierMixin<DownloadTaskCenterState, DownloadTaskRowState> {
  static const int _pageSize = 20;
  static const Duration _mergeDebounce = Duration(milliseconds: 800);
  static const Duration _longDisconnectThreshold = Duration(minutes: 2);
  static const Duration _pollingInterval = Duration(seconds: 30);

  /// 两次「SSE 触发的第一页 merge」之间的最小时间间隔——防止死循环。
  /// 用户主动 refresh / applyFilter 走独立入口，不受影响。
  static const Duration _minMergeInterval = Duration(seconds: 15);
  static const List<Duration> _reconnectDelays = <Duration>[
    Duration(seconds: 1),
    Duration(seconds: 2),
    Duration(seconds: 4),
    Duration(seconds: 8),
    Duration(seconds: 16),
    Duration(seconds: 30),
  ];

  DownloadTaskFilterState _activeFilter = DownloadTaskFilterState.initial;

  StreamSubscription<DownloadTaskStreamEvent>? _streamSubscription;
  Timer? _reconnectTimer;
  Timer? _pollingTimer;
  Timer? _mergeDebounceTimer;
  int _reconnectAttempt = 0;
  DateTime? _disconnectStartedAt;
  DateTime? _lastFirstPageMergeAt;

  final List<DownloadTaskStreamEvent> _pendingStreamEvents =
      <DownloadTaskStreamEvent>[];
  bool _isStreamFlushScheduled = false;

  @override
  int get pageSize => _pageSize;

  @override
  String get initialLoadErrorText => '下载任务加载失败，请稍后重试';

  @override
  String get loadMoreErrorText => '加载更多失败，请点击重试';

  @override
  PagedListState<DownloadTaskRowState> pagedOf(DownloadTaskCenterState s) =>
      s.paged;

  @override
  DownloadTaskCenterState applyPaged(
    DownloadTaskCenterState s,
    PagedListState<DownloadTaskRowState> paged,
  ) => s.copyWith(paged: paged);

  @override
  Future<PaginatedResponseDto<DownloadTaskRowState>> fetchPage(
    int page,
    int pageSize,
  ) async {
    final filter = _activeFilter;
    final response = await ref
        .read(downloadsApiProvider)
        .getDownloadTasks(
          page: page,
          pageSize: pageSize,
          clientId: filter.clientId,
          movieNumber:
              filter.normalizedSearch.isEmpty ? null : filter.normalizedSearch,
          downloadState: filter.stateFilter.apiValue,
          sort: 'created_at:desc',
        );
    final liveById = _liveOverlayById();
    return PaginatedResponseDto<DownloadTaskRowState>(
      items: response.items
          .map(
            (task) => DownloadTaskRowState(task: task, live: liveById[task.id]),
          )
          .toList(growable: false),
      page: response.page,
      pageSize: response.pageSize,
      total: response.total,
      syncedAt: response.syncedAt,
    );
  }

  @override
  Future<DownloadTaskCenterState> build() async {
    attachDisposeGuard();
    ref.onDispose(() {
      _cancelStream();
      _cancelReconnectTimer();
      _cancelPollingTimer();
      _cancelMergeDebounce();
      _resetPendingStreamEvents();
    });
    unawaited(_loadClientOptionsInBackground());
    final paged = await loadInitialPage();
    return DownloadTaskCenterState.initial.copyWith(
      paged: paged,
      filter: _activeFilter,
    );
  }

  /// 保留态刷新（不切 AsyncLoading）：Activity 页面手动"刷新"入口用。
  /// 失败时返回中文错误消息由页面 toast；成功返回 null。
  @override
  Future<String?> refresh() async {
    return super.refresh();
  }

  /// 切换筛选条件：更新 filter → 保留旧 items + 顶部薄进度条 → 重新拉第一页。
  /// 若 SSE 在跑则用新参数重连。遵循「筛选状态驱动」范式：值对象不变则短路。
  Future<void> applyFilter(DownloadTaskFilterState next) async {
    if (_activeFilter == next) return;
    _activeFilter = next;

    final wasStreamOn =
        state.value?.streamState == DownloadTaskStreamState.live ||
            state.value?.streamState == DownloadTaskStreamState.connecting ||
            state.value?.streamState == DownloadTaskStreamState.reconnecting ||
            state.value?.streamState == DownloadTaskStreamState.polling;
    if (wasStreamOn) {
      _cancelStream();
      _cancelReconnectTimer();
      _cancelPollingTimer();
      _cancelMergeDebounce();
      _resetPendingStreamEvents();
      final current = state.value;
      if (current != null) {
        state = AsyncData(
          current.copyWith(streamState: DownloadTaskStreamState.idle),
        );
      }
    }

    final current = state.value;
    if (current == null) {
      // 尚未 build 完成，走 mixin 的 reload 兜底。
      await reload(updateBaseState: (s) => s.copyWith(filter: next));
      if (wasStreamOn && !isDisposed) {
        unawaited(connectStream());
      }
      return;
    }

    // 用 isReloading（而非 AsyncLoading）：pane 保留筛选栏 + 速度栏 + 旧 items，
    // 只在列表顶叠 LinearProgressIndicator。避免整页 spinner 造成的筛选栏闪烁。
    invalidateInFlightLoadMore();
    state = AsyncData(current.copyWith(filter: next, isReloading: true));

    try {
      final firstPage = await loadInitialPage();
      if (isDisposed) return;
      final now = state.value ?? current;
      state = AsyncData(
        now.copyWith(paged: firstPage, isReloading: false),
      );
    } catch (_) {
      if (isDisposed) return;
      // 切换失败保留旧 items（filter 已变——用户可再选触发重试）。
      final now = state.value ?? current;
      state = AsyncData(now.copyWith(isReloading: false));
    }

    if (wasStreamOn && !isDisposed) {
      unawaited(connectStream());
    }
  }

  Future<void> connectStream() async {
    if (isDisposed) return;
    final now = state.value;
    if (now == null) return;
    final s = now.streamState;
    if (s == DownloadTaskStreamState.connecting ||
        s == DownloadTaskStreamState.live ||
        s == DownloadTaskStreamState.polling) {
      return;
    }
    await _openStream();
  }

  void disconnectStream() {
    final now = state.value;
    if (now == null) return;
    if (now.streamState == DownloadTaskStreamState.idle) return;
    _cancelStream();
    _cancelReconnectTimer();
    _cancelPollingTimer();
    _cancelMergeDebounce();
    _resetPendingStreamEvents();
    _disconnectStartedAt = null;
    _reconnectAttempt = 0;
    state = AsyncData(
      now.copyWith(streamState: DownloadTaskStreamState.idle),
    );
  }

  Future<void> pauseTask(int taskId) async {
    final now = state.value;
    if (now == null || now.pendingActionTaskIds.contains(taskId)) return;
    final currentDownloadState = _stateOf(now, taskId);
    _addPending(taskId);
    try {
      await ref.read(downloadsApiProvider).pauseDownloadTask(taskId);
      if (isDisposed) return;
      _patchRowState(
        taskId,
        downloadState:
            currentDownloadState == 'seeding' ||
                    currentDownloadState == 'completed'
                ? 'completed'
                : 'paused',
      );
    } finally {
      _removePending(taskId);
    }
  }

  Future<void> resumeTask(int taskId) async {
    final now = state.value;
    if (now == null || now.pendingActionTaskIds.contains(taskId)) return;
    _addPending(taskId);
    try {
      await ref.read(downloadsApiProvider).resumeDownloadTask(taskId);
      if (isDisposed) return;
      _patchRowState(taskId, downloadState: 'downloading');
    } finally {
      _removePending(taskId);
    }
  }

  Future<void> deleteTask(int taskId, {required bool deleteFiles}) async {
    final now = state.value;
    if (now == null || now.pendingActionTaskIds.contains(taskId)) return;
    _addPending(taskId);
    try {
      await ref
          .read(downloadsApiProvider)
          .deleteDownloadTask(taskId, deleteFiles: deleteFiles);
      if (isDisposed) return;
      _removeItemById(taskId);
    } finally {
      _removePending(taskId);
    }
  }

  // ─── internal ───────────────────────────────────────────────────────────

  Map<int, DownloadTaskProgressDto?> _liveOverlayById() {
    final overlay = <int, DownloadTaskProgressDto?>{};
    final current = state.value;
    if (current == null) return overlay;
    for (final row in current.paged.items) {
      overlay[row.task.id] = row.live;
    }
    return overlay;
  }

  Future<void> _loadClientOptionsInBackground() async {
    try {
      final clients = await ref
          .read(downloadClientsApiProvider)
          .getClients();
      if (isDisposed) return;
      final options = clients
          .map(
            (client) => DownloadClientOption(
              id: client.id,
              name: client.name,
              kind: client.kind,
            ),
          )
          .toList(growable: false);
      final names = <int, String>{};
      final kinds = <int, DownloadClientKind>{};
      for (final client in clients) {
        names[client.id] = client.name;
        kinds[client.id] = client.kind;
      }
      final current = state.value;
      if (current == null) return;
      state = AsyncData(
        current.copyWith(
          clientOptions: options,
          clientNames: names,
          clientKinds: kinds,
        ),
      );
    } catch (_) {
      // 静默：客户端名加载失败展示 `客户端 #<id>` 兜底。
    }
  }

  Future<void> _openStream() async {
    _cancelReconnectTimer();
    _cancelPollingTimer();
    _updateStreamState(DownloadTaskStreamState.connecting);

    if (_disconnectStartedAt != null &&
        DateTime.now().difference(_disconnectStartedAt!) >
            _longDisconnectThreshold) {
      try {
        final paged = await loadInitialPage();
        if (isDisposed) return;
        final current = state.value;
        if (current != null) {
          state = AsyncData(current.copyWith(paged: paged));
        }
      } catch (_) {}
    }

    try {
      final stream = ref
          .read(downloadsApiProvider)
          .streamDownloadTasks(
            clientId: _activeFilter.clientId,
            movieNumber: _activeFilter.normalizedSearch.isEmpty
                ? null
                : _activeFilter.normalizedSearch,
          );
      _streamSubscription = stream.listen(
        _handleStreamEvent,
        onError: _handleStreamError,
        onDone: _handleStreamDone,
        cancelOnError: false,
      );
      _reconnectAttempt = 0;
      _disconnectStartedAt = null;
      _updateStreamState(DownloadTaskStreamState.live);
    } on SseEventStreamUnsupportedException {
      _startPollingFallback();
    } catch (_) {
      _scheduleReconnect();
    }
  }

  void _handleStreamEvent(DownloadTaskStreamEvent event) {
    if (isDisposed) return;
    _pendingStreamEvents.add(event);
    if (_isStreamFlushScheduled) return;
    _isStreamFlushScheduled = true;
    scheduleMicrotask(_flushPendingStreamEvents);
  }

  void _flushPendingStreamEvents() {
    _isStreamFlushScheduled = false;
    if (isDisposed || _pendingStreamEvents.isEmpty) return;
    final events = List<DownloadTaskStreamEvent>.from(_pendingStreamEvents);
    _pendingStreamEvents.clear();

    final initial = state.value;
    if (initial == null) return;

    final firstPageComplete =
        initial.paged.items.length >= initial.paged.total;

    var current = initial;
    var scheduleFirstPageMerge = false;
    for (final event in events) {
      switch (event.kind) {
        case DownloadTaskStreamEventKind.heartbeat:
          if (current.streamState != DownloadTaskStreamState.live) {
            current = current.copyWith(
              streamState: DownloadTaskStreamState.live,
            );
          }
          break;
        case DownloadTaskStreamEventKind.snapshot:
          for (final item in event.snapshotItems) {
            final patched = _applyProgress(current, item);
            if (patched != null) {
              current = patched;
              final row = _rowById(current, item.taskId);
              if (row != null && !_rowMatchesFilter(row)) {
                current = _dropUnmatchedRow(current, item.taskId);
              }
            } else if (firstPageComplete && _progressMatchesFilter(item)) {
              scheduleFirstPageMerge = true;
            }
          }
          break;
        case DownloadTaskStreamEventKind.taskUpdated:
          final progress = event.progress;
          if (progress == null) break;
          final beforeState = _stateOf(current, progress.taskId);
          final patched = _applyProgress(current, progress);
          if (patched != null) {
            current = patched;
            final row = _rowById(current, progress.taskId);
            if (row != null && !_rowMatchesFilter(row)) {
              current = _dropUnmatchedRow(current, progress.taskId);
            } else if (beforeState != null &&
                (beforeState != 'completed' && beforeState != 'seeding') &&
                (progress.downloadState == 'completed' ||
                    progress.downloadState == 'seeding')) {
              scheduleFirstPageMerge = true;
            }
          } else if (firstPageComplete && _progressMatchesFilter(progress)) {
            scheduleFirstPageMerge = true;
          }
          break;
        case DownloadTaskStreamEventKind.taskRemoved:
          final removed = event.removed;
          if (removed == null) break;
          current = _dropUnmatchedRow(current, removed.taskId);
          break;
        case DownloadTaskStreamEventKind.clientTransfer:
          final transfer = event.clientTransfer;
          if (transfer == null) break;
          final existing = current.clientTransfers[transfer.clientId] ??
              DownloadClientTransferState(clientId: transfer.clientId);
          final nextMap = Map<int, DownloadClientTransferState>.of(
            current.clientTransfers,
          );
          nextMap[transfer.clientId] = existing.copyWith(
            downloadSpeedBytes: transfer.downloadSpeedBytes,
            uploadSpeedBytes: transfer.uploadSpeedBytes,
          );
          current = current.copyWith(clientTransfers: nextMap);
          break;
        case DownloadTaskStreamEventKind.clientHealth:
          final health = event.clientHealth;
          if (health == null) break;
          final existing = current.clientTransfers[health.clientId] ??
              DownloadClientTransferState(clientId: health.clientId);
          final nextMap = Map<int, DownloadClientTransferState>.of(
            current.clientTransfers,
          );
          nextMap[health.clientId] = existing.copyWith(
            isAvailable: health.isAvailable,
            unavailableMessage:
                health.isAvailable ? null : health.message ?? '客户端不可用',
            downloadSpeedBytes: health.isAvailable ? null : 0,
            uploadSpeedBytes: health.isAvailable ? null : 0,
          );
          current = current.copyWith(clientTransfers: nextMap);
          break;
        case DownloadTaskStreamEventKind.unknown:
          break;
      }
    }

    if (!identical(current, initial)) {
      state = AsyncData(current);
    }

    if (scheduleFirstPageMerge && _canScheduleFirstPageMerge()) {
      _scheduleFirstPageMerge();
    }
  }

  bool _canScheduleFirstPageMerge() {
    final last = _lastFirstPageMergeAt;
    if (last == null) return true;
    return DateTime.now().difference(last) >= _minMergeInterval;
  }

  DownloadTaskCenterState? _applyProgress(
    DownloadTaskCenterState state,
    DownloadTaskProgressDto progress,
  ) {
    final items = state.paged.items;
    final index = items.indexWhere((row) => row.task.id == progress.taskId);
    if (index < 0) return null;
    final row = items[index];
    final next = List<DownloadTaskRowState>.from(items);
    next[index] = row.copyWith(live: progress);
    return state.copyWith(
      paged: state.paged.copyWith(
        items: List<DownloadTaskRowState>.unmodifiable(next),
      ),
    );
  }

  String? _stateOf(DownloadTaskCenterState state, int taskId) {
    for (final row in state.paged.items) {
      if (row.task.id == taskId) return row.downloadState;
    }
    return null;
  }

  DownloadTaskRowState? _rowById(DownloadTaskCenterState state, int taskId) {
    for (final row in state.paged.items) {
      if (row.task.id == taskId) return row;
    }
    return null;
  }

  void _patchRowState(int taskId, {required String downloadState}) {
    final current = state.value;
    if (current == null) return;
    final items = current.paged.items;
    final index = items.indexWhere((row) => row.task.id == taskId);
    if (index < 0) return;
    final row = items[index];
    final next = List<DownloadTaskRowState>.from(items);
    next[index] = row.copyWith(
      task: row.task.copyWith(downloadState: downloadState),
      // The last SSE snapshot may still contain the pre-action state.
      live: null,
    );
    state = AsyncData(
      current.copyWith(
        paged: current.paged.copyWith(
          items: List<DownloadTaskRowState>.unmodifiable(next),
        ),
      ),
    );
  }

  void _removeItemById(int taskId) {
    final current = state.value;
    if (current == null) return;
    final next = current.paged.items
        .where((row) => row.task.id != taskId)
        .toList(growable: false);
    if (next.length == current.paged.items.length) return;
    final total = current.paged.total > 0 ? current.paged.total - 1 : 0;
    state = AsyncData(
      current.copyWith(
        paged: current.paged.copyWith(
          items: List<DownloadTaskRowState>.unmodifiable(next),
          total: total,
          hasMore: next.length < total,
        ),
      ),
    );
  }

  DownloadTaskCenterState _dropUnmatchedRow(
    DownloadTaskCenterState state,
    int taskId,
  ) {
    final next = state.paged.items
        .where((row) => row.task.id != taskId)
        .toList(growable: false);
    if (next.length == state.paged.items.length) return state;
    final total = state.paged.total > 0 ? state.paged.total - 1 : 0;
    return state.copyWith(
      paged: state.paged.copyWith(
        items: List<DownloadTaskRowState>.unmodifiable(next),
        total: total,
        hasMore: next.length < total,
      ),
    );
  }

  void _addPending(int taskId) {
    final current = state.value;
    if (current == null) return;
    final next = Set<int>.of(current.pendingActionTaskIds)..add(taskId);
    state = AsyncData(current.copyWith(pendingActionTaskIds: next));
  }

  void _removePending(int taskId) {
    if (isDisposed) return;
    final current = state.value;
    if (current == null) return;
    final next = Set<int>.of(current.pendingActionTaskIds)..remove(taskId);
    state = AsyncData(current.copyWith(pendingActionTaskIds: next));
  }

  void _updateStreamState(DownloadTaskStreamState next) {
    if (isDisposed) return;
    final current = state.value;
    if (current == null) return;
    if (current.streamState == next) return;
    state = AsyncData(current.copyWith(streamState: next));
  }

  bool _progressMatchesFilter(DownloadTaskProgressDto progress) {
    if (_activeFilter.clientId != null &&
        progress.clientId != _activeFilter.clientId) {
      return false;
    }
    final search = _activeFilter.normalizedSearch;
    if (search.isNotEmpty) {
      final movie = progress.movieNumber?.trim().toUpperCase() ?? '';
      if (movie != search.toUpperCase()) return false;
    }
    final expectedState = _activeFilter.stateFilter.apiValue;
    if (expectedState != null && progress.downloadState != expectedState) {
      return false;
    }
    return true;
  }

  bool _rowMatchesFilter(DownloadTaskRowState row) {
    if (_activeFilter.clientId != null &&
        row.task.clientId != _activeFilter.clientId) {
      return false;
    }
    final search = _activeFilter.normalizedSearch;
    if (search.isNotEmpty) {
      final movie = row.task.movieNumber?.trim().toUpperCase() ?? '';
      if (movie != search.toUpperCase()) return false;
    }
    final expectedState = _activeFilter.stateFilter.apiValue;
    if (expectedState != null && row.downloadState != expectedState) {
      return false;
    }
    return true;
  }

  void _scheduleFirstPageMerge() {
    _cancelMergeDebounce();
    _mergeDebounceTimer = Timer(_mergeDebounce, () async {
      if (isDisposed) return;
      try {
        final firstPage = await loadInitialPage();
        if (isDisposed) return;
        final current = state.value;
        if (current == null) return;
        final merged = _mergeUpsertFirstPage(
          current.paged.items,
          firstPage.items,
        );
        state = AsyncData(
          current.copyWith(
            paged: current.paged.copyWith(
              items: List<DownloadTaskRowState>.unmodifiable(merged),
              total: firstPage.total,
              hasMore: merged.length < firstPage.total,
              syncedAt: firstPage.syncedAt,
            ),
          ),
        );
        _lastFirstPageMergeAt = DateTime.now();
      } catch (_) {
        // 后台合并失败静默；下一次事件或用户刷新兜底。
      }
    });
  }

  void _handleStreamError(Object error, StackTrace stackTrace) {
    if (isDisposed) return;
    if (error is SseEventStreamUnsupportedException) {
      _startPollingFallback();
      return;
    }
    _scheduleReconnect();
  }

  void _handleStreamDone() {
    if (isDisposed) return;
    final current = state.value;
    if (current == null) return;
    if (current.streamState == DownloadTaskStreamState.polling) return;
    _scheduleReconnect();
  }

  void _scheduleReconnect() {
    if (isDisposed) return;
    _disconnectStartedAt ??= DateTime.now();
    _updateStreamState(DownloadTaskStreamState.reconnecting);

    final delay = _reconnectDelays[_reconnectAttempt.clamp(
      0,
      _reconnectDelays.length - 1,
    )];
    _reconnectAttempt += 1;
    _cancelReconnectTimer();
    _reconnectTimer = Timer(delay, () async {
      if (isDisposed) return;
      await _streamSubscription?.cancel();
      _streamSubscription = null;
      await _openStream();
    });
  }

  void _startPollingFallback() {
    _cancelReconnectTimer();
    _resetPendingStreamEvents();
    _updateStreamState(DownloadTaskStreamState.polling);
    _cancelPollingTimer();
    _pollingTimer = Timer.periodic(_pollingInterval, (_) async {
      if (isDisposed) return;
      try {
        final firstPage = await loadInitialPage();
        if (isDisposed) return;
        final current = state.value;
        if (current == null) return;
        state = AsyncData(current.copyWith(paged: firstPage));
      } catch (_) {
        // 保留最后一次成功状态。
      }
    });
  }

  void _cancelStream() {
    _streamSubscription?.cancel();
    _streamSubscription = null;
  }

  void _cancelReconnectTimer() {
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
  }

  void _cancelPollingTimer() {
    _pollingTimer?.cancel();
    _pollingTimer = null;
  }

  void _cancelMergeDebounce() {
    _mergeDebounceTimer?.cancel();
    _mergeDebounceTimer = null;
  }

  void _resetPendingStreamEvents() {
    _pendingStreamEvents.clear();
    _isStreamFlushScheduled = false;
  }

  List<DownloadTaskRowState> _mergeUpsertFirstPage(
    List<DownloadTaskRowState> current,
    List<DownloadTaskRowState> firstPage,
  ) {
    final firstPageIds = <int>{};
    final byId = <int, DownloadTaskRowState>{};
    for (final row in current) {
      byId[row.task.id] = row;
    }
    final head = <DownloadTaskRowState>[];
    for (final row in firstPage) {
      firstPageIds.add(row.task.id);
      final existing = byId[row.task.id];
      if (existing != null) {
        // Preserve local `live` overlay across re-fetch (already handled in
        // fetchPage → PagedListState.fromFirstPage, but keep the overlay
        // from anything the SSE already patched in between).
        head.add(existing.copyWith(task: row.task));
      } else {
        head.add(row);
      }
    }
    // 保留分页 2+ 已加载但不在首页快照里的行。
    final tail = current
        .where((row) => !firstPageIds.contains(row.task.id))
        .toList(growable: false);
    return <DownloadTaskRowState>[...head, ...tail];
  }
}
