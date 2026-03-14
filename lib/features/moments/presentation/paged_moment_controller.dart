import 'dart:collection';

import 'package:flutter/material.dart';
import 'package:sakuramedia/core/network/paginated_response_dto.dart';
import 'package:sakuramedia/features/media/data/media_point_list_item_dto.dart';
import 'package:sakuramedia/features/movies/data/movie_list_item_dto.dart';
import 'package:sakuramedia/features/movies/data/movie_media_thumbnail_dto.dart';

typedef MomentPageFetcher =
    Future<PaginatedResponseDto<MediaPointListItemDto>> Function(
      int page,
      int pageSize,
      String sort,
    );

typedef MediaThumbnailFetcher =
    Future<List<MovieMediaThumbnailDto>> Function({required int mediaId});

enum MomentSortOrder {
  latest(label: '最新', apiValue: 'created_at:desc'),
  earliest(label: '最早', apiValue: 'created_at:asc');

  const MomentSortOrder({required this.label, required this.apiValue});

  final String label;
  final String apiValue;
}

class MomentListItem {
  const MomentListItem({
    required this.pointId,
    required this.mediaId,
    required this.movieNumber,
    required this.offsetSeconds,
    required this.createdAt,
    required this.thumbnail,
  });

  final int pointId;
  final int mediaId;
  final String movieNumber;
  final int offsetSeconds;
  final DateTime? createdAt;
  final MovieMediaThumbnailDto? thumbnail;

  MovieImageDto? get image => thumbnail?.image;
}

class PagedMomentController extends ChangeNotifier {
  PagedMomentController({
    required this.fetchPage,
    required this.fetchMediaThumbnails,
    this.initialPage = 1,
    this.pageSize = 20,
    this.loadMoreTriggerOffset = 300,
    this.initialLoadErrorText = '时刻列表加载失败，请稍后重试',
    this.loadMoreErrorText = '加载更多失败，请点击重试',
    ScrollController? scrollController,
  }) : scrollController = scrollController ?? ScrollController(),
       _currentPage = initialPage - 1;

  final MomentPageFetcher fetchPage;
  final MediaThumbnailFetcher fetchMediaThumbnails;
  final int initialPage;
  final int pageSize;
  final double loadMoreTriggerOffset;
  final String initialLoadErrorText;
  final String loadMoreErrorText;
  final ScrollController scrollController;

  final List<MomentListItem> _items = <MomentListItem>[];
  final Map<int, List<MovieMediaThumbnailDto>> _thumbnailCache =
      <int, List<MovieMediaThumbnailDto>>{};

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
  MomentSortOrder _sortOrder = MomentSortOrder.latest;

  List<MomentListItem> get items =>
      UnmodifiableListView<MomentListItem>(_items);
  bool get isInitialLoading => _isInitialLoading;
  bool get isLoadingMore => _isLoadingMore;
  bool get hasLoadedOnce => _hasLoadedOnce;
  bool get hasMore => _hasMore;
  String? get initialErrorMessage => _initialErrorMessage;
  String? get loadMoreErrorMessage => _loadMoreErrorMessage;
  int get currentPage => _currentPage;
  int get total => _total;
  MomentSortOrder get sortOrder => _sortOrder;

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

  Future<void> setSortOrder(MomentSortOrder nextOrder) async {
    if (_sortOrder == nextOrder) {
      return;
    }
    _sortOrder = nextOrder;
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
      final response = await fetchPage(nextPage, pageSize, _sortOrder.apiValue);
      if (_isDisposed) {
        return;
      }
      final hydratedItems = await _hydrateItems(response.items);
      if (_isDisposed) {
        return;
      }

      if (reset) {
        _items
          ..clear()
          ..addAll(hydratedItems);
      } else {
        _items.addAll(hydratedItems);
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

  Future<List<MomentListItem>> _hydrateItems(
    List<MediaPointListItemDto> rawItems,
  ) async {
    final mediaIds =
        rawItems.map((item) => item.mediaId).where((id) => id > 0).toSet();
    await Future.wait(mediaIds.map(_ensureThumbnailsLoaded));
    return rawItems
        .map(
          (item) => MomentListItem(
            pointId: item.pointId,
            mediaId: item.mediaId,
            movieNumber: item.movieNumber,
            offsetSeconds: item.offsetSeconds,
            createdAt: item.createdAt,
            thumbnail: _resolveThumbnail(
              mediaId: item.mediaId,
              offsetSeconds: item.offsetSeconds,
            ),
          ),
        )
        .toList(growable: false);
  }

  Future<void> _ensureThumbnailsLoaded(int mediaId) async {
    if (_thumbnailCache.containsKey(mediaId)) {
      return;
    }
    try {
      _thumbnailCache[mediaId] = await fetchMediaThumbnails(mediaId: mediaId);
    } catch (_) {
      _thumbnailCache[mediaId] = const <MovieMediaThumbnailDto>[];
    }
  }

  MovieMediaThumbnailDto? _resolveThumbnail({
    required int mediaId,
    required int offsetSeconds,
  }) {
    final thumbnails = _thumbnailCache[mediaId];
    if (thumbnails == null || thumbnails.isEmpty) {
      return null;
    }
    for (final thumbnail in thumbnails) {
      if (thumbnail.offsetSeconds == offsetSeconds) {
        return thumbnail;
      }
    }
    MovieMediaThumbnailDto? closest;
    var closestDistance = 1 << 30;
    for (final thumbnail in thumbnails) {
      final distance = (thumbnail.offsetSeconds - offsetSeconds).abs();
      if (distance < closestDistance) {
        closestDistance = distance;
        closest = thumbnail;
      }
    }
    return closest;
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
