import 'dart:collection';

import 'package:flutter/material.dart';
import 'package:sakuramedia/core/network/paginated_response_dto.dart';

typedef PagedLoadFetcher<T> =
    Future<PaginatedResponseDto<T>> Function(int page, int pageSize);

class PagedLoadController<T> extends ChangeNotifier {
  PagedLoadController({
    required PagedLoadFetcher<T> fetchPage,
    this.initialPage = 1,
    this.pageSize = 24,
    this.loadMoreTriggerOffset = 300,
    required this.initialLoadErrorText,
    required this.loadMoreErrorText,
    ScrollController? scrollController,
  }) : _fetchPage = fetchPage,
       scrollController = scrollController ?? ScrollController(),
       _currentPage = initialPage - 1;

  final PagedLoadFetcher<T> _fetchPage;
  final int initialPage;
  final int pageSize;
  final double loadMoreTriggerOffset;
  final String initialLoadErrorText;
  final String loadMoreErrorText;
  final ScrollController scrollController;

  final List<T> _items = <T>[];

  bool _isInitialLoading = false;
  bool _isLoadingMore = false;
  bool _hasLoadedOnce = false;
  bool _hasMore = true;
  bool _isInitialized = false;
  bool _isDisposed = false;
  bool _scrollListenerAttached = false;
  String? _initialErrorMessage;

  /// loadMore 失败后的错误文案；下一次 [loadMore] / [refresh] / [reload] 会清空。
  ///
  /// **调用方约定**：当本字段非 null 时，UI 必须渲染一个带「重试」按钮的 footer
  /// （常见做法是 `AppPagedLoadMoreFooter` 或 `SliverPagedAsyncSection` 内置的
  /// footer），否则用户没有恢复分页的手段——[_handleScroll] 在 error 存续期间不再
  /// 自动重试，避免用户上下滑动就把失败请求反复打出去。
  String? _loadMoreErrorMessage;
  int _currentPage;
  int _total = 0;
  DateTime? _syncedAt;

  List<T> get items => UnmodifiableListView<T>(_items);
  bool get isInitialLoading => _isInitialLoading;
  bool get isLoadingMore => _isLoadingMore;
  bool get hasLoadedOnce => _hasLoadedOnce;
  bool get hasMore => _hasMore;
  String? get initialErrorMessage => _initialErrorMessage;
  String? get loadMoreErrorMessage => _loadMoreErrorMessage;
  int get currentPage => _currentPage;
  int get total => _total;

  /// 当前这批数据的抓取时间（本地时区），整批共用同一个值；暂无数据时为 `null`。
  DateTime? get syncedAt => _syncedAt;

  @protected
  List<T> get mutableItems => _items;

  @protected
  bool get isDisposed => _isDisposed;

  @protected
  int get mutableTotal => _total;

  @protected
  set mutableTotal(int value) {
    _total = value;
  }

  @protected
  Future<PaginatedResponseDto<T>> fetchPage(int page, int pageSize) {
    return _fetchPage(page, pageSize);
  }

  @protected
  void notifyListenersSafely() {
    if (_isDisposed) {
      return;
    }
    notifyListeners();
  }

  Future<void> initialize() async {
    if (_isInitialized) {
      return;
    }
    _isInitialized = true;
    await _loadPage(reset: true);
  }

  Future<void> reload() async {
    _isInitialized = true;
    await _loadPage(reset: true);
  }

  Future<void> refresh() async {
    if (_isInitialLoading || _isLoadingMore) {
      return;
    }
    final response = await fetchPage(initialPage, pageSize);
    if (_isDisposed) {
      return;
    }
    _replaceItems(response.items);
    _currentPage = response.page;
    _total = response.total;
    _syncedAt = response.syncedAt;
    _hasMore = _items.length < _total;
    _hasLoadedOnce = true;
    _initialErrorMessage = null;
    _loadMoreErrorMessage = null;
    notifyListenersSafely();
  }

  Future<void> loadMore() async {
    if (_isInitialLoading || _isLoadingMore || !_hasMore) {
      return;
    }
    await _loadPage(reset: false);
  }

  void attachScrollListener() {
    if (_scrollListenerAttached) {
      return;
    }
    scrollController.addListener(_handleScroll);
    _scrollListenerAttached = true;
  }

  void detachScrollListener() {
    if (!_scrollListenerAttached) {
      return;
    }
    scrollController.removeListener(_handleScroll);
    _scrollListenerAttached = false;
  }

  void _replaceItems(Iterable<T> items) {
    _items
      ..clear()
      ..addAll(items);
  }

  Future<void> _loadPage({required bool reset}) async {
    final nextPage = reset ? initialPage : _currentPage + 1;

    if (reset) {
      _isInitialLoading = true;
      _isLoadingMore = false;
      _initialErrorMessage = null;
      _loadMoreErrorMessage = null;
      _currentPage = initialPage - 1;
      _total = 0;
      _syncedAt = null;
      _hasMore = true;
      _hasLoadedOnce = false;
      _items.clear();
      notifyListenersSafely();
    } else {
      _isLoadingMore = true;
      _loadMoreErrorMessage = null;
      notifyListenersSafely();
    }

    try {
      final response = await fetchPage(nextPage, pageSize);
      if (_isDisposed) {
        return;
      }

      if (reset) {
        _replaceItems(response.items);
      } else {
        _items.addAll(response.items);
      }

      _currentPage = response.page;
      _total = response.total;
      _syncedAt = response.syncedAt;
      _hasLoadedOnce = true;
      _hasMore = _items.length < _total;
      _initialErrorMessage = null;
      _loadMoreErrorMessage = null;
    } catch (_) {
      if (_isDisposed) {
        return;
      }
      if (reset) {
        _initialErrorMessage = initialLoadErrorText;
        _hasMore = false;
      } else {
        _loadMoreErrorMessage = loadMoreErrorText;
        _hasMore = _items.length < _total;
      }
    } finally {
      if (!_isDisposed) {
        _isInitialLoading = false;
        _isLoadingMore = false;
        notifyListenersSafely();
      }
    }
  }

  // loadMore 失败后 `_loadMoreErrorMessage != null` 会屏蔽自动重试（避免上下滑动
  // 反复触发失败请求）。恢复分页的唯一入口是调用方渲染的 footer 重试按钮——见
  // `_loadMoreErrorMessage` 字段说明。
  void _handleScroll() {
    if (!scrollController.hasClients ||
        _isInitialLoading ||
        _isLoadingMore ||
        _loadMoreErrorMessage != null ||
        !_hasMore) {
      return;
    }
    final position = scrollController.position;
    if (position.pixels >= position.maxScrollExtent - loadMoreTriggerOffset) {
      loadMore();
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    detachScrollListener();
    scrollController.dispose();
    super.dispose();
  }
}
