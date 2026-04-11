import 'dart:collection';

import 'package:flutter/material.dart';
import 'package:sakuramedia/core/network/api_exception.dart';
import 'package:sakuramedia/core/network/api_error_message.dart';
import 'package:sakuramedia/core/network/paginated_response_dto.dart';
import 'package:sakuramedia/features/movies/data/movie_list_item_dto.dart';

typedef MovieSummaryPageFetcher =
    Future<PaginatedResponseDto<MovieListItemDto>> Function(
      int page,
      int pageSize,
    );

typedef MovieSubscriptionWriter =
    Future<void> Function({required String movieNumber});

typedef MovieUnsubscriptionWriter =
    Future<void> Function({required String movieNumber, bool deleteMedia});

enum MovieSubscriptionToggleStatus {
  subscribed,
  unsubscribed,
  blockedByMedia,
  failed,
  ignored,
}

class MovieSubscriptionToggleResult {
  const MovieSubscriptionToggleResult({required this.status, this.message});

  const MovieSubscriptionToggleResult.subscribed()
    : this(status: MovieSubscriptionToggleStatus.subscribed);

  const MovieSubscriptionToggleResult.unsubscribed()
    : this(status: MovieSubscriptionToggleStatus.unsubscribed);

  const MovieSubscriptionToggleResult.blockedByMedia()
    : this(status: MovieSubscriptionToggleStatus.blockedByMedia);

  const MovieSubscriptionToggleResult.failed({required String message})
    : this(status: MovieSubscriptionToggleStatus.failed, message: message);

  const MovieSubscriptionToggleResult.ignored()
    : this(status: MovieSubscriptionToggleStatus.ignored);

  final MovieSubscriptionToggleStatus status;
  final String? message;
}

class PagedMovieSummaryController extends ChangeNotifier {
  PagedMovieSummaryController({
    required this.fetchPage,
    required this.subscribeMovie,
    required this.unsubscribeMovie,
    this.initialPage = 1,
    this.pageSize = 24,
    this.loadMoreTriggerOffset = 300,
    this.initialLoadErrorText = '最新入库影片加载失败，请稍后重试',
    this.loadMoreErrorText = '加载更多失败，请点击重试',
    ScrollController? scrollController,
  }) : scrollController = scrollController ?? ScrollController(),
       _currentPage = initialPage - 1;

  final MovieSummaryPageFetcher fetchPage;
  final MovieSubscriptionWriter subscribeMovie;
  final MovieUnsubscriptionWriter unsubscribeMovie;
  final int initialPage;
  final int pageSize;
  final double loadMoreTriggerOffset;
  final String initialLoadErrorText;
  final String loadMoreErrorText;
  final ScrollController scrollController;

  final List<MovieListItemDto> _items = <MovieListItemDto>[];
  final Set<String> _updatingMovieNumbers = <String>{};

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

  List<MovieListItemDto> get items =>
      UnmodifiableListView<MovieListItemDto>(_items);
  bool get isInitialLoading => _isInitialLoading;
  bool get isLoadingMore => _isLoadingMore;
  bool get hasLoadedOnce => _hasLoadedOnce;
  bool get hasMore => _hasMore;
  String? get initialErrorMessage => _initialErrorMessage;
  String? get loadMoreErrorMessage => _loadMoreErrorMessage;
  int get currentPage => _currentPage;
  int get total => _total;

  bool isSubscriptionUpdating(String movieNumber) {
    return _updatingMovieNumbers.contains(movieNumber);
  }

  Future<MovieSubscriptionToggleResult> toggleSubscription({
    required String movieNumber,
  }) async {
    final index = _items.indexWhere((item) => item.movieNumber == movieNumber);
    if (index == -1 || _updatingMovieNumbers.contains(movieNumber)) {
      return const MovieSubscriptionToggleResult.ignored();
    }

    final movie = _items[index];
    _updatingMovieNumbers.add(movieNumber);
    _safeNotifyListeners();

    try {
      if (movie.isSubscribed) {
        await unsubscribeMovie(movieNumber: movieNumber, deleteMedia: false);
        _items[index] = movie.copyWith(isSubscribed: false);
        return const MovieSubscriptionToggleResult.unsubscribed();
      }

      await subscribeMovie(movieNumber: movieNumber);
      _items[index] = movie.copyWith(isSubscribed: true);
      return const MovieSubscriptionToggleResult.subscribed();
    } catch (error) {
      if (_isBlockedByMedia(error)) {
        return const MovieSubscriptionToggleResult.blockedByMedia();
      }
      return MovieSubscriptionToggleResult.failed(
        message: apiErrorMessage(
          error,
          fallback: movie.isSubscribed ? '取消订阅影片失败' : '订阅影片失败',
        ),
      );
    } finally {
      _updatingMovieNumbers.remove(movieNumber);
      _safeNotifyListeners();
    }
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
      final response = await fetchPage(nextPage, pageSize);
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

  bool _isBlockedByMedia(Object error) {
    return error is ApiException &&
        error.error?.code == 'movie_subscription_has_media';
  }

  @override
  void dispose() {
    _isDisposed = true;
    detachScrollListener();
    scrollController.dispose();
    super.dispose();
  }
}
