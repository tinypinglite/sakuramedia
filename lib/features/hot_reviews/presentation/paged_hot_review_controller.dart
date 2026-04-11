import 'dart:collection';

import 'package:flutter/material.dart';
import 'package:sakuramedia/core/network/paginated_response_dto.dart';
import 'package:sakuramedia/features/hot_reviews/data/hot_review_list_item_dto.dart';
import 'package:sakuramedia/features/hot_reviews/data/hot_review_period.dart';

typedef HotReviewPageFetcher =
    Future<PaginatedResponseDto<HotReviewListItemDto>> Function(
      int page,
      int pageSize,
      HotReviewPeriod period,
    );

class PagedHotReviewController extends ChangeNotifier {
  PagedHotReviewController({
    required this.fetchPage,
    this.initialPage = 1,
    this.pageSize = 20,
    this.loadMoreTriggerOffset = 300,
    this.initialLoadErrorText = '热评加载失败，请稍后重试',
    this.loadMoreErrorText = '加载更多失败，请点击重试',
    ScrollController? scrollController,
  }) : scrollController = scrollController ?? ScrollController(),
       _currentPage = initialPage - 1;

  final HotReviewPageFetcher fetchPage;
  final int initialPage;
  final int pageSize;
  final double loadMoreTriggerOffset;
  final String initialLoadErrorText;
  final String loadMoreErrorText;
  final ScrollController scrollController;

  final List<HotReviewListItemDto> _items = <HotReviewListItemDto>[];

  bool _isInitialLoading = false;
  bool _isLoadingMore = false;
  bool _hasLoadedOnce = false;
  bool _hasMore = true;
  bool _isInitialized = false;
  bool _isDisposed = false;
  bool _scrollListenerAttached = false;
  String? _initialErrorMessage;
  String? _loadMoreErrorMessage;
  int _currentPage;
  int _total = 0;
  HotReviewPeriod _period = HotReviewPeriod.weekly;

  List<HotReviewListItemDto> get items =>
      UnmodifiableListView<HotReviewListItemDto>(_items);
  bool get isInitialLoading => _isInitialLoading;
  bool get isLoadingMore => _isLoadingMore;
  bool get hasLoadedOnce => _hasLoadedOnce;
  bool get hasMore => _hasMore;
  String? get initialErrorMessage => _initialErrorMessage;
  String? get loadMoreErrorMessage => _loadMoreErrorMessage;
  int get currentPage => _currentPage;
  int get total => _total;
  HotReviewPeriod get period => _period;

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
    final response = await fetchPage(initialPage, pageSize, _period);
    if (_isDisposed) {
      return;
    }
    _items
      ..clear()
      ..addAll(response.items);
    _currentPage = response.page;
    _total = response.total;
    _hasMore = _items.length < _total;
    _hasLoadedOnce = true;
    _initialErrorMessage = null;
    _loadMoreErrorMessage = null;
    _safeNotifyListeners();
  }

  Future<void> setPeriod(HotReviewPeriod nextPeriod) async {
    if (_period == nextPeriod) {
      return;
    }
    _period = nextPeriod;
    if (scrollController.hasClients) {
      scrollController.jumpTo(0);
    }
    await reload();
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

  Future<void> _loadPage({required bool reset}) async {
    final nextPage = reset ? initialPage : _currentPage + 1;

    if (reset) {
      _isInitialLoading = true;
      _isLoadingMore = false;
      _initialErrorMessage = null;
      _loadMoreErrorMessage = null;
      _currentPage = initialPage - 1;
      _total = 0;
      _hasMore = true;
      _hasLoadedOnce = false;
      _items.clear();
      _safeNotifyListeners();
    } else {
      _isLoadingMore = true;
      _loadMoreErrorMessage = null;
      _safeNotifyListeners();
    }

    try {
      final response = await fetchPage(nextPage, pageSize, _period);
      if (_isDisposed) {
        return;
      }

      if (reset) {
        _items
          ..clear()
          ..addAll(response.items);
      } else {
        _items.addAll(response.items);
      }

      _currentPage = response.page;
      _total = response.total;
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
        _safeNotifyListeners();
      }
    }
  }

  void _handleScroll() {
    if (!scrollController.hasClients ||
        _isInitialLoading ||
        _isLoadingMore ||
        !_hasMore) {
      return;
    }
    final position = scrollController.position;
    if (position.pixels >= position.maxScrollExtent - loadMoreTriggerOffset) {
      loadMore();
    }
  }

  void _safeNotifyListeners() {
    if (_isDisposed) {
      return;
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _isDisposed = true;
    detachScrollListener();
    scrollController.dispose();
    super.dispose();
  }
}
