import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:sakuramedia/core/network/api_error_message.dart';
import 'package:sakuramedia/core/network/paginated_response_dto.dart';

enum FilterUpdatePhase { idle, waiting, loading, failed }

/// 服务端筛选结果与当前 UI 筛选条件之间的同步状态。
///
/// 筛选条件始终先写入业务 State；[waiting] 是尾随防抖窗口，[loading] 是实际
/// 请求中。两者期间分页条目仍是上一次成功结果，页面应保留列表；只有实际请求
/// 持续一小段时间后，结果区才需要显示进度反馈。
@immutable
class FilterUpdateState {
  const FilterUpdateState._(this.phase, this.errorMessage);

  const FilterUpdateState.idle() : this._(FilterUpdatePhase.idle, null);

  const FilterUpdateState.waiting() : this._(FilterUpdatePhase.waiting, null);

  const FilterUpdateState.loading() : this._(FilterUpdatePhase.loading, null);

  const FilterUpdateState.failed(String message)
    : this._(FilterUpdatePhase.failed, message);

  final FilterUpdatePhase phase;
  final String? errorMessage;

  bool get isIdle => phase == FilterUpdatePhase.idle;
  bool get isWaiting => phase == FilterUpdatePhase.waiting;
  bool get isLoading => phase == FilterUpdatePhase.loading;
  bool get hasFailed => phase == FilterUpdatePhase.failed;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FilterUpdateState &&
          other.phase == phase &&
          other.errorMessage == errorMessage;

  @override
  int get hashCode => Object.hash(phase, errorMessage);
}

/// 尾随防抖 + latest-wins 的异步请求协调器。
///
/// 已经发出的请求不会被强制取消，但新的 [schedule] / [runNow] 会立即使旧请求
/// 的 request id 失效；调用方在写 State 前用 [isCurrent] 判定即可。
class DebouncedLatestRequest {
  DebouncedLatestRequest({this.delay = const Duration(milliseconds: 250)});

  final Duration delay;

  Timer? _timer;
  Completer<void>? _pendingCompleter;
  int _generation = 0;
  bool _disposed = false;

  bool isCurrent(int requestId) => !_disposed && requestId == _generation;

  Future<void> schedule(Future<void> Function(int requestId) action) {
    final requestId = _beginRequest();
    final completer = Completer<void>();
    _pendingCompleter = completer;
    _timer = Timer(delay, () {
      _timer = null;
      unawaited(_runAction(requestId, action, completer));
    });
    return completer.future;
  }

  Future<void> runNow(Future<void> Function(int requestId) action) {
    final requestId = _beginRequest();
    final completer = Completer<void>();
    _pendingCompleter = completer;
    unawaited(_runAction(requestId, action, completer));
    return completer.future;
  }

  int _beginRequest() {
    _timer?.cancel();
    _timer = null;
    _completePending();
    return ++_generation;
  }

  Future<void> _runAction(
    int requestId,
    Future<void> Function(int requestId) action,
    Completer<void> completer,
  ) async {
    try {
      await action(requestId);
    } catch (_) {
      // Provider 把错误转换为可观察 State；筛选入口通常由 UI fire-and-forget
      // 调用，因此协调器不把异常重新抛回事件循环。
    } finally {
      if (identical(_pendingCompleter, completer)) {
        _pendingCompleter = null;
      }
      if (!completer.isCompleted) completer.complete();
    }
  }

  void cancel() {
    _generation++;
    _timer?.cancel();
    _timer = null;
    _completePending();
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    cancel();
  }

  void _completePending() {
    final completer = _pendingCompleter;
    _pendingCompleter = null;
    if (completer != null && !completer.isCompleted) completer.complete();
  }
}

/// 分页列表状态的通用值对象：
/// - [items]：已加载的条目（累加）。
/// - [currentPage]：最近一次成功加载的页码；0 表示尚未加载。
/// - [total]：后端返回的总条数；用于计算 [hasMore]。
/// - [hasMore]：`items.length < total`；分页失败会保留原判定。
/// - [syncedAt]：整批数据的抓取时间（本地时区）；跟随最近一次成功响应更新。
/// - [isLoadingMore] / [loadMoreErrorMessage]：仅描述「下一页」加载态；
///   首次加载的 loading/error 由外层 [AsyncValue] 表达（[AsyncLoading]/[AsyncError]）。
/// - [filterUpdate]：当前筛选条件是否仍在等待服务端结果。
///
/// 可空字段 [syncedAt] / [loadMoreErrorMessage] 的 [copyWith] 使用哨兵：
/// 省略参数 = 保持原值；显式传 `null` = 置空。
@immutable
class PagedListState<T> {
  const PagedListState({
    this.items = const [],
    this.currentPage = 0,
    this.total = 0,
    this.hasMore = false,
    this.syncedAt,
    this.isLoadingMore = false,
    this.loadMoreErrorMessage,
    this.filterUpdate = const FilterUpdateState.idle(),
  });

  final List<T> items;
  final int currentPage;
  final int total;
  final bool hasMore;
  final DateTime? syncedAt;
  final bool isLoadingMore;
  final String? loadMoreErrorMessage;
  final FilterUpdateState filterUpdate;

  bool get isEmpty => items.isEmpty;
  bool get isNotEmpty => items.isNotEmpty;

  /// 首页响应直接组装为初始 State。
  factory PagedListState.fromFirstPage(PaginatedResponseDto<T> response) {
    return PagedListState<T>(
      items: List<T>.unmodifiable(response.items),
      currentPage: response.page,
      total: response.total,
      hasMore: response.items.length < response.total,
      syncedAt: response.syncedAt,
    );
  }

  PagedListState<T> copyWith({
    List<T>? items,
    int? currentPage,
    int? total,
    bool? hasMore,
    Object? syncedAt = _kSentinel,
    bool? isLoadingMore,
    Object? loadMoreErrorMessage = _kSentinel,
    FilterUpdateState? filterUpdate,
  }) {
    return PagedListState<T>(
      items: items ?? this.items,
      currentPage: currentPage ?? this.currentPage,
      total: total ?? this.total,
      hasMore: hasMore ?? this.hasMore,
      syncedAt: identical(syncedAt, _kSentinel)
          ? this.syncedAt
          : syncedAt as DateTime?,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      loadMoreErrorMessage: identical(loadMoreErrorMessage, _kSentinel)
          ? this.loadMoreErrorMessage
          : loadMoreErrorMessage as String?,
      filterUpdate: filterUpdate ?? this.filterUpdate,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is PagedListState<T> &&
        listEquals(other.items, items) &&
        other.currentPage == currentPage &&
        other.total == total &&
        other.hasMore == hasMore &&
        other.syncedAt == syncedAt &&
        other.isLoadingMore == isLoadingMore &&
        other.loadMoreErrorMessage == loadMoreErrorMessage &&
        other.filterUpdate == filterUpdate;
  }

  @override
  int get hashCode => Object.hash(
    Object.hashAll(items),
    currentPage,
    total,
    hasMore,
    syncedAt,
    isLoadingMore,
    loadMoreErrorMessage,
    filterUpdate,
  );
}

const Object _kSentinel = Object();

/// [PagedListState] 的局部补丁原语：事件/乐观更新后对已加载列表做**就地**
/// 修正，避免整页 invalidate 重拉。
///
/// 三个操作都保持不可变契约（新列表一律 `List.unmodifiable`）与其余分页字段
/// 不变（currentPage / syncedAt / isLoadingMore / loadMoreErrorMessage 原样
/// 透传）；只动 items / total / hasMore 三者中受影响的。
extension PagedListStatePatch<T> on PagedListState<T> {
  /// 移除所有匹配项：同步扣减 [PagedListState.total]（下限 0）并重算
  /// [PagedListState.hasMore]。无匹配时原样返回自身。
  PagedListState<T> removeWhere(bool Function(T) predicate) {
    final nextItems = items.where((item) => !predicate(item)).toList();
    if (nextItems.length == items.length) {
      return this;
    }
    final removed = items.length - nextItems.length;
    final nextTotal = (total - removed).clamp(0, 1 << 30).toInt();
    return copyWith(
      items: List<T>.unmodifiable(nextItems),
      total: nextTotal,
      hasMore: nextItems.length < nextTotal,
    );
  }

  /// 把**第一个**匹配项替换成 `update(item)` 的结果；不改 [PagedListState.total]
  /// / [PagedListState.hasMore]（条数未变）。无匹配时原样返回自身。
  PagedListState<T> patchWhere(bool Function(T) matches, T Function(T) update) {
    final index = items.indexWhere(matches);
    if (index < 0) {
      return this;
    }
    final nextItems = List<T>.of(items);
    nextItems[index] = update(items[index]);
    return copyWith(items: List<T>.unmodifiable(nextItems));
  }

  /// 前置 upsert：命中则替换第一个匹配项（条数不变，total/hasMore 不动）；
  /// 未命中则在**列表头部**插入 [item]，`total + 1` 并重算 [PagedListState.hasMore]。
  PagedListState<T> upsertFront(T item, {required bool Function(T) matches}) {
    final index = items.indexWhere(matches);
    if (index >= 0) {
      final nextItems = List<T>.of(items);
      nextItems[index] = item;
      return copyWith(items: List<T>.unmodifiable(nextItems));
    }
    final nextItems = List<T>.unmodifiable(<T>[item, ...items]);
    final nextTotal = total + 1;
    return copyWith(
      items: nextItems,
      total: nextTotal,
      hasMore: nextItems.length < nextTotal,
    );
  }
}

/// `$AsyncNotifier<S>` 的分页 mixin，把 `PagedLoadController` 的语义
/// 迁移到 Riverpod 侧。首例见 `features/media/presentation/providers/`。
///
/// 使用范式（S 中携带 [PagedListState<T>] 段 + 额外字段，如 filter/selection）：
///
/// ```dart
/// @Riverpod(keepAlive: true, retry: kNoAsyncNotifierRetry)
/// class MediaBrowse extends _$MediaBrowse
///     with PagedAsyncNotifierMixin<MediaBrowseState, MediaListItemDto> {
///   @override int get pageSize => 30;
///   @override String get initialLoadErrorText => '媒体列表加载失败，请稍后重试';
///   @override String get loadMoreErrorText => '加载更多媒体失败，请点击重试';
///
///   @override
///   PagedListState<MediaListItemDto> pagedOf(MediaBrowseState s) => s.paged;
///   @override
///   MediaBrowseState applyPaged(MediaBrowseState s, PagedListState<MediaListItemDto> p) =>
///       s.copyWith(paged: p);
///
///   @override
///   Future<PaginatedResponseDto<MediaListItemDto>> fetchPage(int page, int pageSize) =>
///       ref.read(mediaApiProvider).getMediaList(page: page, pageSize: pageSize, ...);
///
///   @override
///   Future<MediaBrowseState> build() async {
///     attachDisposeGuard();
///     final paged = await loadInitialPage();
///     return MediaBrowseState.initial.copyWith(paged: paged);
///   }
/// }
/// ```
///
/// 若 S 本身就是 `PagedListState<T>`（无额外字段），`pagedOf` / `applyPaged` 是恒等。
///
/// 生命周期与 `AsyncNotifier` 一致：首次加载态由外层 [AsyncLoading] 表达；成功后
/// State 内的 [PagedListState.items] 累加；loadMore 失败保留原列表 + 挂 error text；
/// 关闭 provider 自动重试（`AsyncNotifierProvider` 传 `retry: (_, __) => null`
/// 或 `@Riverpod(..., retry: kNoAsyncNotifierRetry)`）避免失败态里 `build()` 打爆后端。
mixin PagedAsyncNotifierMixin<S, T> on $AsyncNotifier<S> {
  bool _disposed = false;

  /// 「首页重置」代次：每次 [reload] / [refresh] 开始时 +1。
  /// 正在飞的 [loadMore] 在 await 返回后若发现代次已变，即视为结果作废、
  /// 不再写回 State——避免用旧 `paged.items` 覆盖 reload 后的新首页。
  int _generation = 0;

  @protected
  bool get isDisposed => _disposed;

  @protected
  int get initialPage => 1;

  @protected
  int get pageSize;

  @protected
  String get initialLoadErrorText;

  @protected
  String get loadMoreErrorText;

  @protected
  Future<PaginatedResponseDto<T>> fetchPage(int page, int pageSize);

  /// 从 S 里取出 [PagedListState] 段。
  @protected
  PagedListState<T> pagedOf(S state);

  /// 把新的 [PagedListState] 应用回 S。
  @protected
  S applyPaged(S state, PagedListState<T> paged);

  /// 必须在 `build()` 首行调用；防 dispose 后 `state = ...` 静默失败或抛错。
  @protected
  void attachDisposeGuard() {
    ref.onDispose(() => _disposed = true);
  }

  /// 让**当前正在飞的 [loadMore]** 视为过期结果（回来后不再写回 State）。
  ///
  /// 子类在自定义「重置首页」路径（比如筛选切换想要保留旧 items + 展示结果区
  /// 轻量进度层而不走 [reload] 的 AsyncLoading 分支）时，
  /// 在**开始拉取新第一页之前**调用一次，避免旧 loadMore 覆盖新首页。
  @protected
  void invalidateInFlightLoadMore() {
    _generation++;
  }

  /// 抓第一页并构造 [PagedListState]。抛出交给 [AsyncNotifier] 自动转 [AsyncError]。
  @protected
  Future<PagedListState<T>> loadInitialPage() async {
    final response = await fetchPage(initialPage, pageSize);
    return PagedListState<T>.fromFirstPage(response);
  }

  /// 强制重新加载：切 [AsyncLoading] → 拉第一页 → 覆盖回 State。
  ///
  /// 若子类要在 reload 前对 S 打补丁（如清空多选/清空辅助集合），传 [updateBaseState]。
  /// 尚未成功 build 时（还在 loading / 初次失败）走 `ref.invalidateSelf()`。
  Future<void> reload({S Function(S current)? updateBaseState}) async {
    _generation++;
    final current = state.value;
    if (current == null) {
      ref.invalidateSelf();
      try {
        await future;
      } catch (_) {
        // 已切 AsyncError，UI 侧展示错误；这里吞异常避免污染调用点。
      }
      return;
    }
    final baseState = updateBaseState != null
        ? updateBaseState(current)
        : current;
    state = AsyncLoading<S>();
    final next = await AsyncValue.guard<S>(() async {
      final firstPage = await loadInitialPage();
      return applyPaged(baseState, firstPage);
    });
    if (!_disposed) {
      state = next;
    }
  }

  /// 保留态刷新：不切 loading；失败返回中文错误消息由页面 toast。
  ///
  /// 子类可覆写以在刷新前清辅助集合（如 `_deleteEnabledMediaIds`），例如：
  /// ```dart
  /// @override
  /// Future<String?> refresh() async {
  ///   final current = state.value;
  ///   if (current != null) {
  ///     state = AsyncData(current.copyWith(deleteEnabledMediaIds: const {}));
  ///   }
  ///   return super.refresh();
  /// }
  /// ```
  Future<String?> refresh() async {
    final current = state.value;
    if (current == null) {
      await reload();
      return null;
    }
    if (pagedOf(current).isLoadingMore) {
      return null;
    }
    _generation++;
    try {
      final response = await fetchPage(initialPage, pageSize);
      if (_disposed) return null;
      final currentAfter = state.value ?? current;
      state = AsyncData(
        applyPaged(currentAfter, PagedListState<T>.fromFirstPage(response)),
      );
      return null;
    } catch (error) {
      return apiErrorMessage(error, fallback: initialLoadErrorText);
    }
  }

  /// 加载下一页。未 build / 已在加载 / 无更多时短路。
  /// 失败保留原列表并把 [loadMoreErrorText] 写进 State。
  Future<void> loadMore() async {
    final current = state.value;
    if (current == null) return;
    final paged = pagedOf(current);
    if (paged.isLoadingMore || !paged.hasMore) return;

    // 抢占当前代次；reload / refresh 期间飞出去的响应用它来判「已作废」。
    final generation = _generation;

    state = AsyncData(
      applyPaged(
        current,
        paged.copyWith(isLoadingMore: true, loadMoreErrorMessage: null),
      ),
    );

    try {
      final response = await fetchPage(paged.currentPage + 1, pageSize);
      if (_disposed || generation != _generation) return;
      // 合并基线取 await **之后**的分页态，不是入口处的 `paged` 快照：await 期间
      // mutation 广播可能已对 items 做过就地补丁（取消订阅摘行、删除等），拿旧快照
      // 整体覆盖会把补丁抹掉、让数据短暂回退。失败分支一直是这么写的，这里对齐。
      final currentAfter = state.value ?? current;
      final pagedAfter = pagedOf(currentAfter);
      final merged = List<T>.unmodifiable(<T>[
        ...pagedAfter.items,
        ...response.items,
      ]);
      state = AsyncData(
        applyPaged(
          currentAfter,
          pagedAfter.copyWith(
            items: merged,
            currentPage: response.page,
            total: response.total,
            syncedAt: response.syncedAt,
            hasMore: merged.length < response.total,
            isLoadingMore: false,
            loadMoreErrorMessage: null,
          ),
        ),
      );
    } catch (_) {
      if (_disposed || generation != _generation) return;
      final currentAfter = state.value ?? current;
      final currentPaged = pagedOf(currentAfter);
      state = AsyncData(
        applyPaged(
          currentAfter,
          currentPaged.copyWith(
            isLoadingMore: false,
            loadMoreErrorMessage: loadMoreErrorText,
            hasMore: currentPaged.items.length < currentPaged.total,
          ),
        ),
      );
    }
  }
}

/// 筛选驱动分页 mixin：统一「UI 先写筛选 → 保留旧列表 → 防抖请求 →
/// latest-wins 写回」语义。
///
/// 约定：`F` 是不可变值对象（`==` 即"筛选未变"）；`fetchPage` 从 [activeFilter]
/// 读参数；UI 改筛选后调 [applyFilterState]。State 里的 filter 字段由
/// [applyFilterToState] 负责写入（连带清多选等副作用）。
///
/// ```dart
/// @Riverpod(keepAlive: true, retry: kNoAsyncNotifierRetry)
/// class MediaBrowse extends _$MediaBrowse
///     with PagedAsyncNotifierMixin<MediaBrowseState, MediaListItemDto>,
///          FilterablePagedAsyncNotifierMixin<MediaBrowseState, MediaListItemDto, MediaBrowseFilterState> {
///   @override
///   MediaBrowseFilterState get initialFilter => MediaBrowseFilterState.initial;
///
///   @override
///   MediaBrowseState applyFilterToState(MediaBrowseState s, MediaBrowseFilterState filter) =>
///       s.copyWith(filter: filter, selectedIds: const <int>{});
///
///   @override
///   Future<MediaBrowseState> build() async {
///     attachDisposeGuard();
///     final paged = await loadInitialPage();
///     return MediaBrowseState(paged: paged, filter: activeFilter);
///   }
/// }
/// ```
mixin FilterablePagedAsyncNotifierMixin<S, T, F>
    on PagedAsyncNotifierMixin<S, T> {
  /// 首次 build 的默认筛选。
  @protected
  F get initialFilter;

  late F _activeFilter = initialFilter;

  late final DebouncedLatestRequest _filterRequests = DebouncedLatestRequest(
    delay: filterDebounceDuration,
  );
  bool _filterDisposeAttached = false;

  /// 当前生效的筛选；`fetchPage` 从它读参数拼请求。
  @protected
  F get activeFilter => _activeFilter;

  /// 筛选控件的尾随防抖时长。业务域原则上保持默认值；测试可覆写为零。
  @protected
  Duration get filterDebounceDuration => const Duration(milliseconds: 250);

  @protected
  String get filterUpdateErrorText => '筛选结果更新失败，请重试';

  /// 把新筛选值写进 State（连带清多选等副作用）。注意把 filter 字段本身也写入。
  @protected
  S applyFilterToState(S state, F filter);

  void _ensureFilterDisposeGuard() {
    if (_filterDisposeAttached) return;
    _filterDisposeAttached = true;
    ref.onDispose(_filterRequests.dispose);
  }

  /// 应用新筛选状态。值对象相等则短路；变化时先同步更新 State，再尾随
  /// 防抖请求第一页。返回 Future 在请求完成或被更新请求取代后正常结束。
  Future<void> applyFilterState(F next) {
    if (_activeFilter == next) return Future<void>.value();
    _activeFilter = next;
    _ensureFilterDisposeGuard();
    _writePendingFilter(next, filterUpdate: const FilterUpdateState.waiting());
    return _filterRequests.schedule(_loadSelectedFilter);
  }

  /// 立即重试当前筛选，跳过防抖窗口。
  Future<void> retryFilter() {
    _ensureFilterDisposeGuard();
    _writePendingFilter(
      _activeFilter,
      applyFilter: false,
      filterUpdate: const FilterUpdateState.loading(),
    );
    return _filterRequests.runNow(_loadSelectedFilter);
  }

  void _writePendingFilter(
    F next, {
    required FilterUpdateState filterUpdate,
    bool applyFilter = true,
  }) {
    final current = state.value;
    if (current == null) return;

    invalidateInFlightLoadMore();
    final currentPaged = pagedOf(current);
    final pendingPaged = currentPaged.copyWith(
      isLoadingMore: false,
      loadMoreErrorMessage: null,
      filterUpdate: filterUpdate,
    );
    final base = applyPaged(current, pendingPaged);
    state = AsyncData(applyFilter ? applyFilterToState(base, next) : base);
  }

  Future<void> _loadSelectedFilter(int requestId) async {
    final current = state.value;
    if (current == null) {
      // 初次 build 尚未形成可保留的数据，沿用首屏 AsyncValue 语义。
      await super.reload();
      return;
    }

    if (isDisposed || !_filterRequests.isCurrent(requestId)) return;
    state = AsyncData(
      applyPaged(
        current,
        pagedOf(current).copyWith(
          isLoadingMore: false,
          loadMoreErrorMessage: null,
          filterUpdate: const FilterUpdateState.loading(),
        ),
      ),
    );

    try {
      final firstPage = await loadInitialPage();
      if (isDisposed || !_filterRequests.isCurrent(requestId)) return;
      final now = state.value ?? current;
      state = AsyncData(applyPaged(now, firstPage));
    } catch (error) {
      if (isDisposed || !_filterRequests.isCurrent(requestId)) return;
      final now = state.value ?? current;
      state = AsyncData(
        applyPaged(
          now,
          pagedOf(now).copyWith(
            isLoadingMore: false,
            loadMoreErrorMessage: null,
            filterUpdate: FilterUpdateState.failed(
              apiErrorMessage(error, fallback: filterUpdateErrorText),
            ),
          ),
        ),
      );
    }
  }

  @override
  Future<void> loadMore() {
    final current = state.value;
    if (current != null && !pagedOf(current).filterUpdate.isIdle) {
      return Future<void>.value();
    }
    return super.loadMore();
  }

  @override
  Future<String?> refresh() async {
    await retryFilter();
    final current = state.value;
    return current == null ? null : pagedOf(current).filterUpdate.errorMessage;
  }

  @override
  Future<void> reload({S Function(S current)? updateBaseState}) {
    if (_filterDisposeAttached) _filterRequests.cancel();
    return super.reload(updateBaseState: updateBaseState);
  }
}
