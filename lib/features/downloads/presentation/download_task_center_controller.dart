import 'dart:async';
import 'dart:collection';

import 'package:flutter/foundation.dart';
import 'package:sakuramedia/core/network/api_error_message.dart';
import 'package:sakuramedia/core/network/paginated_response_dto.dart';
import 'package:sakuramedia/core/network/sse_event_stream_client.dart';
import 'package:sakuramedia/features/configuration/data/api/download_clients_api.dart';
import 'package:sakuramedia/features/downloads/data/download_request_dto.dart';
import 'package:sakuramedia/features/downloads/data/download_task_stream_event_dto.dart';
import 'package:sakuramedia/features/downloads/data/downloads_api.dart';
import 'package:sakuramedia/features/downloads/presentation/download_task_filter_state.dart';

/// 供筛选栏下拉展示的下载客户端选项：id + 展示名。
class DownloadClientOption {
  const DownloadClientOption({required this.id, required this.name});

  final int id;
  final String name;
}

/// 下载任务的实时连接状态。
///
/// - [idle]: 页面未进入下载 tab，未连接（活动中心切走后进入此态，保留列表快照）。
/// - [connecting]: 首次连接中。
/// - [live]: 正常收流。
/// - [reconnecting]: 断线，退避重连中。
/// - [polling]: SSE 不受支持（主要 Web 端），30s 轮询兜底。
enum DownloadTaskStreamState { idle, connecting, live, reconnecting, polling }

/// 单个任务的行状态：`task` 打底 + `live` 覆盖实时字段。
class DownloadTaskRowState {
  const DownloadTaskRowState({required this.task, this.live});

  final DownloadTaskDto task;
  final DownloadTaskProgressDto? live;

  DownloadTaskRowState copyWith({
    DownloadTaskDto? task,
    Object? live = _sentinel,
  }) {
    return DownloadTaskRowState(
      task: task ?? this.task,
      live:
          identical(live, _sentinel)
              ? this.live
              : live as DownloadTaskProgressDto?,
    );
  }

  double get progress => live?.progress ?? task.progress;
  String get downloadState => live?.downloadState ?? task.downloadState;
}

const Object _sentinel = Object();

/// 单个客户端的实时传输 + 健康状态。
class DownloadClientTransferState {
  const DownloadClientTransferState({
    required this.clientId,
    this.downloadSpeedBytes = 0,
    this.uploadSpeedBytes = 0,
    this.isAvailable = true,
    this.unavailableMessage,
  });

  final int clientId;
  final int downloadSpeedBytes;
  final int uploadSpeedBytes;
  final bool isAvailable;
  final String? unavailableMessage;

  DownloadClientTransferState copyWith({
    int? downloadSpeedBytes,
    int? uploadSpeedBytes,
    bool? isAvailable,
    Object? unavailableMessage = _sentinel,
  }) {
    return DownloadClientTransferState(
      clientId: clientId,
      downloadSpeedBytes: downloadSpeedBytes ?? this.downloadSpeedBytes,
      uploadSpeedBytes: uploadSpeedBytes ?? this.uploadSpeedBytes,
      isAvailable: isAvailable ?? this.isAvailable,
      unavailableMessage:
          identical(unavailableMessage, _sentinel)
              ? this.unavailableMessage
              : unavailableMessage as String?,
    );
  }
}

/// 下载任务中心控制器：列表分页 + SSE 实时进度 + 暂停/恢复/删除。
class DownloadTaskCenterController extends ChangeNotifier {
  DownloadTaskCenterController({
    required DownloadsApi downloadsApi,
    required DownloadClientsApi downloadClientsApi,
  }) : _downloadsApi = downloadsApi,
       _downloadClientsApi = downloadClientsApi;

  static const int _pageSize = 20;
  static const Duration _mergeDebounce = Duration(milliseconds: 800);
  static const Duration _longDisconnectThreshold = Duration(minutes: 2);
  static const Duration _pollingInterval = Duration(seconds: 30);

  /// 两次「SSE 触发的第一页 merge」之间的最小时间间隔——防止未预期的死循环
  /// （比如后端签名 URL 每秒变、SSE 推分页外任务的 progress 反复触发 schedule）
  /// 让重拉频率有硬上限。用户主动 refresh / applyFilter / initialize 走独立入口，
  /// 不受这个限流影响。
  static const Duration _minMergeInterval = Duration(seconds: 15);
  static const List<Duration> _reconnectDelays = <Duration>[
    Duration(seconds: 1),
    Duration(seconds: 2),
    Duration(seconds: 4),
    Duration(seconds: 8),
    Duration(seconds: 16),
    Duration(seconds: 30),
  ];

  final DownloadsApi _downloadsApi;
  final DownloadClientsApi _downloadClientsApi;

  bool _initialized = false;
  bool _isInitialLoading = false;
  String? _initialErrorMessage;

  /// 筛选切换等"页面已有内容、只是列表内容要换"的场景，用它区别 [_isInitialLoading]。
  /// pane 层根据它显示轻量顶部 LinearProgressIndicator，而不是把筛选栏/速度栏拿掉换 spinner。
  bool _isReloading = false;
  List<DownloadTaskRowState> _items = const <DownloadTaskRowState>[];
  int _total = 0;
  int _nextPage = 1;
  bool _hasMore = false;
  bool _isLoadingMore = false;
  String? _loadMoreErrorMessage;
  int _loadRequestId = 0;

  // 「筛选状态驱动」范式：filter 是可变字段，_loadFirstPage / loadMore / connectStream
  // 都会读取当前值拼参数；UI 改完必须走 applyFilter/reload 让新参数生效。
  DownloadTaskFilterState _filter = DownloadTaskFilterState.initial;
  List<DownloadClientOption> _clientOptions = const <DownloadClientOption>[];

  DownloadTaskStreamState _streamState = DownloadTaskStreamState.idle;
  StreamSubscription<DownloadTaskStreamEvent>? _streamSubscription;
  Timer? _reconnectTimer;
  Timer? _pollingTimer;
  Timer? _mergeDebounceTimer;
  int _reconnectAttempt = 0;
  DateTime? _disconnectStartedAt;

  /// 最后一次 SSE 触发的 first-page merge 成功完成的时间。用来做 [_minMergeInterval] 限流。
  DateTime? _lastFirstPageMergeAt;
  final List<DownloadTaskStreamEvent> _pendingStreamEvents =
      <DownloadTaskStreamEvent>[];
  bool _isStreamFlushScheduled = false;

  final Map<int, DownloadClientTransferState> _clientTransfers =
      <int, DownloadClientTransferState>{};
  final Map<int, String> _clientNames = <int, String>{};

  final Set<int> _pendingActionTaskIds = <int>{};

  bool _disposed = false;

  bool get initialized => _initialized;
  bool get isInitialLoading => _isInitialLoading;
  bool get isReloading => _isReloading;
  String? get initialErrorMessage => _initialErrorMessage;
  UnmodifiableListView<DownloadTaskRowState> get items =>
      UnmodifiableListView<DownloadTaskRowState>(_items);
  int get total => _total;
  bool get hasMore => _hasMore;
  bool get isLoadingMore => _isLoadingMore;
  String? get loadMoreErrorMessage => _loadMoreErrorMessage;
  DownloadTaskStreamState get streamState => _streamState;
  UnmodifiableMapView<int, DownloadClientTransferState> get clientTransfers =>
      UnmodifiableMapView<int, DownloadClientTransferState>(_clientTransfers);

  int get totalDownloadSpeedBytes {
    var total = 0;
    for (final entry in _clientTransfers.values) {
      if (entry.isAvailable) {
        total += entry.downloadSpeedBytes;
      }
    }
    return total;
  }

  int get totalUploadSpeedBytes {
    var total = 0;
    for (final entry in _clientTransfers.values) {
      if (entry.isAvailable) {
        total += entry.uploadSpeedBytes;
      }
    }
    return total;
  }

  bool isTaskPending(int taskId) => _pendingActionTaskIds.contains(taskId);

  String clientNameOf(int clientId) {
    return _clientNames[clientId] ?? '客户端 #$clientId';
  }

  DownloadTaskFilterState get filter => _filter;

  /// 已知的下载客户端列表，用于筛选栏「客户端」下拉展示。加载完成前是空列表。
  UnmodifiableListView<DownloadClientOption> get clientOptions =>
      UnmodifiableListView<DownloadClientOption>(_clientOptions);

  Future<void> initialize() async {
    if (_initialized || _isInitialLoading) {
      return;
    }
    _isInitialLoading = true;
    _initialErrorMessage = null;
    _notifySafely();

    try {
      unawaited(_loadClientNames());
      await _loadFirstPage();
      if (_disposed) {
        return;
      }
      _initialized = true;
    } catch (error) {
      if (_disposed) {
        return;
      }
      _initialErrorMessage = apiErrorMessage(error, fallback: '下载任务加载失败，请稍后重试');
    } finally {
      if (!_disposed) {
        _isInitialLoading = false;
        _notifySafely();
      }
    }
  }

  Future<void> retryInitialize() async {
    if (_initialized) {
      return;
    }
    await initialize();
  }

  Future<void> refresh() async {
    try {
      await _loadFirstPage();
    } catch (error) {
      // 刷新失败保留原列表；toast 由调用方处理。
      rethrow;
    }
  }

  /// 切换筛选条件：更新 filter → 重新拉第一页 → 若 SSE 在跑则用新参数重连。
  /// 遵循「筛选状态驱动」范式：值对象不变则短路，避免抖动。
  Future<void> applyFilter(DownloadTaskFilterState next) async {
    if (_filter == next) {
      return;
    }
    _filter = next;
    // filter 变了要重启 SSE：因为 movie_number / client_id 是后端订阅参数，直接换掉旧订阅。
    final wasStreamOn =
        _streamState == DownloadTaskStreamState.live ||
        _streamState == DownloadTaskStreamState.connecting ||
        _streamState == DownloadTaskStreamState.reconnecting ||
        _streamState == DownloadTaskStreamState.polling;
    if (wasStreamOn) {
      _cancelStream();
      _cancelReconnectTimer();
      _cancelPollingTimer();
      _cancelMergeDebounce();
      _resetPendingStreamEvents();
      _streamState = DownloadTaskStreamState.idle;
    }
    // 用 _isReloading（而非 _isInitialLoading）：pane 层会保留筛选栏 + 速度栏
    // 和上一次的 items 不动，只在列表顶叠一条 LinearProgressIndicator 作为
    // 轻量加载反馈。避免筛选栏因整页 spinner 分支而从 widget 树被移除→重建
    // 造成的视觉闪烁 + AppSelectField 内部动画/焦点被 reset。
    _isReloading = true;
    _notifySafely();
    try {
      await _loadFirstPage();
    } catch (error) {
      if (_disposed) {
        return;
      }
      // 切换失败时保留旧 items 和旧 filter 状态（filter 已改，items 保留旧值
      // 与新 filter 不完全一致，但比整页错误更好——用户可以再选一次触发重试）。
      // 不覆写 _initialErrorMessage，否则 pane 会走整页 error empty state
      // 把筛选栏也拿掉，回到闪烁问题的原点。
    } finally {
      if (!_disposed) {
        _isReloading = false;
        _notifySafely();
      }
    }
    if (wasStreamOn && !_disposed) {
      unawaited(connectStream());
    }
  }

  Future<void> loadMore() async {
    if (_isLoadingMore || !_hasMore) {
      return;
    }
    _isLoadingMore = true;
    _loadMoreErrorMessage = null;
    _notifySafely();

    try {
      final response = await _fetchTaskPage(_nextPage);
      if (_disposed) {
        return;
      }
      final merged = _mergeAppendRows(_items, response.items);
      _items = merged;
      _nextPage = response.page + 1;
      _total = response.total;
      _hasMore = _items.length < _total;
      _loadMoreErrorMessage = null;
    } catch (_) {
      if (_disposed) {
        return;
      }
      _loadMoreErrorMessage = '加载更多失败，请点击重试';
    } finally {
      if (!_disposed) {
        _isLoadingMore = false;
        _notifySafely();
      }
    }
  }

  Future<void> connectStream() async {
    if (_disposed) {
      return;
    }
    if (_streamState == DownloadTaskStreamState.connecting ||
        _streamState == DownloadTaskStreamState.live ||
        _streamState == DownloadTaskStreamState.polling) {
      return;
    }
    await _openStream();
  }

  void disconnectStream() {
    if (_streamState == DownloadTaskStreamState.idle) {
      return;
    }
    _cancelStream();
    _cancelReconnectTimer();
    _cancelPollingTimer();
    _cancelMergeDebounce();
    _resetPendingStreamEvents();
    _disconnectStartedAt = null;
    _reconnectAttempt = 0;
    _streamState = DownloadTaskStreamState.idle;
    _notifySafely();
  }

  Future<void> pauseTask(int taskId) async {
    if (_pendingActionTaskIds.contains(taskId)) {
      return;
    }
    _pendingActionTaskIds.add(taskId);
    _notifySafely();
    try {
      await _downloadsApi.pauseDownloadTask(taskId);
      if (_disposed) {
        return;
      }
      _patchRowState(taskId, downloadState: 'paused');
    } catch (_) {
      rethrow;
    } finally {
      _pendingActionTaskIds.remove(taskId);
      _notifySafely();
    }
  }

  Future<void> resumeTask(int taskId) async {
    if (_pendingActionTaskIds.contains(taskId)) {
      return;
    }
    _pendingActionTaskIds.add(taskId);
    _notifySafely();
    try {
      await _downloadsApi.resumeDownloadTask(taskId);
      if (_disposed) {
        return;
      }
      _patchRowState(taskId, downloadState: 'downloading');
    } catch (_) {
      rethrow;
    } finally {
      _pendingActionTaskIds.remove(taskId);
      _notifySafely();
    }
  }

  Future<void> deleteTask(int taskId, {required bool deleteFiles}) async {
    if (_pendingActionTaskIds.contains(taskId)) {
      return;
    }
    _pendingActionTaskIds.add(taskId);
    _notifySafely();
    try {
      await _downloadsApi.deleteDownloadTask(taskId, deleteFiles: deleteFiles);
      if (_disposed) {
        return;
      }
      final next = _items.where((row) => row.task.id != taskId).toList();
      if (next.length != _items.length) {
        _items = next;
        _total = _total > 0 ? _total - 1 : 0;
        _hasMore = _items.length < _total;
      }
    } catch (_) {
      rethrow;
    } finally {
      _pendingActionTaskIds.remove(taskId);
      _notifySafely();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _cancelStream();
    _cancelReconnectTimer();
    _cancelPollingTimer();
    _cancelMergeDebounce();
    _resetPendingStreamEvents();
    super.dispose();
  }

  Future<void> _loadFirstPage() async {
    final requestId = ++_loadRequestId;
    final response = await _fetchTaskPage(1);
    if (_disposed || requestId != _loadRequestId) {
      return;
    }
    _items = _mergeReplaceRows(_items, response.items);
    _nextPage = response.page + 1;
    _total = response.total;
    _hasMore = _items.length < _total;
    _loadMoreErrorMessage = null;
  }

  Future<PaginatedResponseDto<DownloadTaskDto>> _fetchTaskPage(int page) {
    return _downloadsApi.getDownloadTasks(
      page: page,
      pageSize: _pageSize,
      clientId: _filter.clientId,
      movieNumber:
          _filter.normalizedSearch.isEmpty ? null : _filter.normalizedSearch,
      downloadState: _filter.stateFilter.apiValue,
      sort: 'created_at:desc',
    );
  }

  Future<void> _loadClientNames() async {
    try {
      final clients = await _downloadClientsApi.getClients();
      if (_disposed) {
        return;
      }
      _clientOptions = clients
          .map((c) => DownloadClientOption(id: c.id, name: c.name))
          .toList(growable: false);
      for (final client in clients) {
        _clientNames[client.id] = client.name;
      }
      _notifySafely();
    } catch (_) {
      // 客户端名加载失败静默：显示 `客户端 #<id>` 兜底。
    }
  }

  Future<void> _openStream() async {
    _cancelReconnectTimer();
    _cancelPollingTimer();
    _streamState = DownloadTaskStreamState.connecting;
    _notifySafely();

    if (_disconnectStartedAt != null &&
        DateTime.now().difference(_disconnectStartedAt!) >
            _longDisconnectThreshold) {
      try {
        await _loadFirstPage();
      } catch (_) {}
      _notifySafely();
    }

    try {
      final stream = _downloadsApi.streamDownloadTasks(
        clientId: _filter.clientId,
        movieNumber:
            _filter.normalizedSearch.isEmpty ? null : _filter.normalizedSearch,
      );
      _streamSubscription = stream.listen(
        _handleStreamEvent,
        onError: _handleStreamError,
        onDone: _handleStreamDone,
        cancelOnError: false,
      );
      _streamState = DownloadTaskStreamState.live;
      _reconnectAttempt = 0;
      _disconnectStartedAt = null;
      _notifySafely();
    } on SseEventStreamUnsupportedException {
      _startPollingFallback();
    } catch (_) {
      _scheduleReconnect();
    }
  }

  void _handleStreamEvent(DownloadTaskStreamEvent event) {
    if (_disposed) {
      return;
    }
    _pendingStreamEvents.add(event);
    if (_isStreamFlushScheduled) {
      return;
    }
    _isStreamFlushScheduled = true;
    scheduleMicrotask(_flushPendingStreamEvents);
  }

  void _flushPendingStreamEvents() {
    _isStreamFlushScheduled = false;
    if (_disposed || _pendingStreamEvents.isEmpty) {
      return;
    }
    final events = List<DownloadTaskStreamEvent>.from(_pendingStreamEvents);
    _pendingStreamEvents.clear();

    // D：仅在「第一页已经拉全（items 数达到 total）」时，才把「SSE 推来一个 items 里
    // 不存在的 taskId」当作「服务端新增任务」的有效信号。否则那 taskId 大概率只是
    // 分页 2+ 里的任务（用户没 loadMore），本地无法通过重拉第一页得到它——但后端
    // 每秒都会推它的 progress，形成 schedule → 800ms fire → schedule 死循环。
    // 每次 fire 拉回的签名 URL 都不同，触发前端图片重加载/闪烁。
    final firstPageComplete = _items.length >= _total;

    var hasChanges = false;
    var scheduleFirstPageMerge = false;
    for (final event in events) {
      switch (event.kind) {
        case DownloadTaskStreamEventKind.heartbeat:
          if (_streamState != DownloadTaskStreamState.live) {
            _streamState = DownloadTaskStreamState.live;
            hasChanges = true;
          }
          break;
        case DownloadTaskStreamEventKind.snapshot:
          for (final item in event.snapshotItems) {
            final didPatch = _applyProgress(item);
            if (didPatch) {
              hasChanges = true;
              // 进度更新后可能改变了 downloadState，重新按 filter 校验：不匹配就 drop 掉。
              final row = _rowById(item.taskId);
              if (row != null && !_rowMatchesFilter(row)) {
                _dropUnmatchedRow(item.taskId);
              }
            } else if (firstPageComplete && _progressMatchesFilter(item)) {
              scheduleFirstPageMerge = true;
            }
          }
          break;
        case DownloadTaskStreamEventKind.taskUpdated:
          final progress = event.progress;
          if (progress == null) {
            break;
          }
          final beforeState = _stateOf(progress.taskId);
          final didPatch = _applyProgress(progress);
          if (didPatch) {
            hasChanges = true;
            final row = _rowById(progress.taskId);
            if (row != null && !_rowMatchesFilter(row)) {
              // 状态翻转到不匹配当前 filter（例如"仅暂停"下任务被恢复了）：从列表移除。
              _dropUnmatchedRow(progress.taskId);
            } else if (beforeState != null &&
                (beforeState != 'completed' && beforeState != 'seeding') &&
                (progress.downloadState == 'completed' ||
                    progress.downloadState == 'seeding')) {
              // 完成/做种翻转：SSE 不带 import_status，去抖刷新第一页拿新状态。
              // 状态翻转是低频事件（每个任务一生只发生一次），不受 D 的分页判定限制。
              scheduleFirstPageMerge = true;
            }
          } else if (firstPageComplete && _progressMatchesFilter(progress)) {
            scheduleFirstPageMerge = true;
          }
          break;
        case DownloadTaskStreamEventKind.taskRemoved:
          final removed = event.removed;
          if (removed == null) {
            break;
          }
          final next =
              _items.where((row) => row.task.id != removed.taskId).toList();
          if (next.length != _items.length) {
            _items = next;
            _total = _total > 0 ? _total - 1 : 0;
            _hasMore = _items.length < _total;
            hasChanges = true;
          }
          break;
        case DownloadTaskStreamEventKind.clientTransfer:
          final transfer = event.clientTransfer;
          if (transfer == null) {
            break;
          }
          final existing =
              _clientTransfers[transfer.clientId] ??
              DownloadClientTransferState(clientId: transfer.clientId);
          _clientTransfers[transfer.clientId] = existing.copyWith(
            downloadSpeedBytes: transfer.downloadSpeedBytes,
            uploadSpeedBytes: transfer.uploadSpeedBytes,
          );
          hasChanges = true;
          break;
        case DownloadTaskStreamEventKind.clientHealth:
          final health = event.clientHealth;
          if (health == null) {
            break;
          }
          final existing =
              _clientTransfers[health.clientId] ??
              DownloadClientTransferState(clientId: health.clientId);
          _clientTransfers[health.clientId] = existing.copyWith(
            isAvailable: health.isAvailable,
            unavailableMessage:
                health.isAvailable ? null : health.message ?? '客户端不可用',
            downloadSpeedBytes: health.isAvailable ? null : 0,
            uploadSpeedBytes: health.isAvailable ? null : 0,
          );
          hasChanges = true;
          break;
        case DownloadTaskStreamEventKind.unknown:
          break;
      }
    }

    if (scheduleFirstPageMerge && _canScheduleFirstPageMerge()) {
      _scheduleFirstPageMerge();
    }
    if (hasChanges) {
      _notifySafely();
    }
  }

  /// A：最小间隔限流。距上一次成功 fire 未满 [_minMergeInterval] 时短路。
  /// D 已在事件分支里过滤了"分页外 unknown taskId"这条主要死循环入口；
  /// 这里作为兜底，防止将来若加了新的 schedule 触发点又出现类似死循环。
  bool _canScheduleFirstPageMerge() {
    final last = _lastFirstPageMergeAt;
    if (last == null) {
      return true;
    }
    return DateTime.now().difference(last) >= _minMergeInterval;
  }

  bool _applyProgress(DownloadTaskProgressDto progress) {
    final index = _items.indexWhere((row) => row.task.id == progress.taskId);
    if (index < 0) {
      return false;
    }
    final row = _items[index];
    final next = List<DownloadTaskRowState>.from(_items);
    next[index] = row.copyWith(live: progress);
    _items = next;
    return true;
  }

  String? _stateOf(int taskId) {
    for (final row in _items) {
      if (row.task.id == taskId) {
        return row.downloadState;
      }
    }
    return null;
  }

  DownloadTaskRowState? _rowById(int taskId) {
    for (final row in _items) {
      if (row.task.id == taskId) {
        return row;
      }
    }
    return null;
  }

  void _patchRowState(int taskId, {required String downloadState}) {
    final index = _items.indexWhere((row) => row.task.id == taskId);
    if (index < 0) {
      return;
    }
    final row = _items[index];
    final next = List<DownloadTaskRowState>.from(_items);
    next[index] = row.copyWith(
      task: row.task.copyWith(downloadState: downloadState),
    );
    _items = next;
  }

  void _scheduleFirstPageMerge() {
    _cancelMergeDebounce();
    _mergeDebounceTimer = Timer(_mergeDebounce, () async {
      if (_disposed) {
        return;
      }
      try {
        final requestId = ++_loadRequestId;
        final response = await _fetchTaskPage(1);
        if (_disposed || requestId != _loadRequestId) {
          return;
        }
        _items = _mergeUpsertFirstPage(_items, response.items);
        _total = response.total;
        _hasMore = _items.length < _total;
        // 记录成功 fire 的时刻，供 A 的最小间隔限流参考。
        _lastFirstPageMergeAt = DateTime.now();
        _notifySafely();
      } catch (_) {
        // 后台合并失败静默；下一次事件或刷新兜底。
      }
    });
  }

  /// SSE 事件的进度是否匹配当前 filter：用于决定不在列表里的行是否触发第一页合并。
  bool _progressMatchesFilter(DownloadTaskProgressDto progress) {
    if (_filter.clientId != null && progress.clientId != _filter.clientId) {
      return false;
    }
    final search = _filter.normalizedSearch;
    if (search.isNotEmpty) {
      final movie = progress.movieNumber?.trim().toUpperCase() ?? '';
      if (movie != search.toUpperCase()) {
        return false;
      }
    }
    final expectedState = _filter.stateFilter.apiValue;
    if (expectedState != null && progress.downloadState != expectedState) {
      return false;
    }
    return true;
  }

  /// 已在列表里的行是否仍匹配当前 filter：不匹配就应该从列表移除。
  bool _rowMatchesFilter(DownloadTaskRowState row) {
    if (_filter.clientId != null && row.task.clientId != _filter.clientId) {
      return false;
    }
    final search = _filter.normalizedSearch;
    if (search.isNotEmpty) {
      final movie = row.task.movieNumber?.trim().toUpperCase() ?? '';
      if (movie != search.toUpperCase()) {
        return false;
      }
    }
    final expectedState = _filter.stateFilter.apiValue;
    if (expectedState != null && row.downloadState != expectedState) {
      return false;
    }
    return true;
  }

  void _dropUnmatchedRow(int taskId) {
    final next = _items.where((row) => row.task.id != taskId).toList();
    if (next.length == _items.length) {
      return;
    }
    _items = next;
    _total = _total > 0 ? _total - 1 : 0;
    _hasMore = _items.length < _total;
  }

  void _handleStreamError(Object error, StackTrace stackTrace) {
    if (_disposed) {
      return;
    }
    if (error is SseEventStreamUnsupportedException) {
      _startPollingFallback();
      return;
    }
    _scheduleReconnect();
  }

  void _handleStreamDone() {
    if (_disposed || _streamState == DownloadTaskStreamState.polling) {
      return;
    }
    _scheduleReconnect();
  }

  void _scheduleReconnect() {
    if (_disposed) {
      return;
    }
    _disconnectStartedAt ??= DateTime.now();
    _streamState = DownloadTaskStreamState.reconnecting;
    _notifySafely();

    final delay =
        _reconnectDelays[_reconnectAttempt.clamp(
          0,
          _reconnectDelays.length - 1,
        )];
    _reconnectAttempt += 1;
    _cancelReconnectTimer();
    _reconnectTimer = Timer(delay, () async {
      if (_disposed) {
        return;
      }
      await _streamSubscription?.cancel();
      _streamSubscription = null;
      await _openStream();
    });
  }

  void _startPollingFallback() {
    _cancelReconnectTimer();
    _resetPendingStreamEvents();
    _streamState = DownloadTaskStreamState.polling;
    _notifySafely();
    _cancelPollingTimer();
    _pollingTimer = Timer.periodic(_pollingInterval, (_) async {
      if (_disposed) {
        return;
      }
      try {
        await _loadFirstPage();
        _notifySafely();
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

  List<DownloadTaskRowState> _mergeReplaceRows(
    List<DownloadTaskRowState> current,
    List<DownloadTaskDto> incoming,
  ) {
    final liveById = <int, DownloadTaskProgressDto?>{};
    for (final row in current) {
      liveById[row.task.id] = row.live;
    }
    return incoming
        .map(
          (task) => DownloadTaskRowState(task: task, live: liveById[task.id]),
        )
        .toList(growable: false);
  }

  List<DownloadTaskRowState> _mergeAppendRows(
    List<DownloadTaskRowState> current,
    List<DownloadTaskDto> incoming,
  ) {
    final next = List<DownloadTaskRowState>.from(current);
    final knownIds = current.map((row) => row.task.id).toSet();
    for (final task in incoming) {
      if (knownIds.contains(task.id)) {
        continue;
      }
      next.add(DownloadTaskRowState(task: task));
    }
    return next;
  }

  List<DownloadTaskRowState> _mergeUpsertFirstPage(
    List<DownloadTaskRowState> current,
    List<DownloadTaskDto> firstPage,
  ) {
    final firstPageIds = <int>{};
    final byId = <int, DownloadTaskRowState>{};
    for (final row in current) {
      byId[row.task.id] = row;
    }
    final head = <DownloadTaskRowState>[];
    for (final task in firstPage) {
      firstPageIds.add(task.id);
      final existing = byId[task.id];
      if (existing != null) {
        head.add(existing.copyWith(task: task));
      } else {
        head.add(DownloadTaskRowState(task: task));
      }
    }
    // Preserve rows already loaded beyond page 1 (not in first page snapshot).
    final tail = current
        .where((row) => !firstPageIds.contains(row.task.id))
        .toList(growable: false);
    return <DownloadTaskRowState>[...head, ...tail];
  }

  void _notifySafely() {
    if (!_disposed) {
      notifyListeners();
    }
  }
}
