import 'package:flutter/foundation.dart';
import 'package:sakuramedia/core/network/api_error_message.dart';
import 'package:sakuramedia/features/movies/data/movie_review_dto.dart';

class MovieDetailReviewController extends ChangeNotifier {
  MovieDetailReviewController({
    required this.movieNumber,
    required this.fetchMovieReviews,
    this.pageSize = 20,
    MovieReviewSort initialSort = MovieReviewSort.hotly,
  }) : _sort = initialSort;

  final String movieNumber;
  final int pageSize;
  final Future<List<MovieReviewDto>> Function({
    required String movieNumber,
    required int page,
    required int pageSize,
    required MovieReviewSort sort,
  })
  fetchMovieReviews;

  MovieReviewSort _sort;
  List<MovieReviewDto> _items = const <MovieReviewDto>[];
  bool _isInitialLoading = false;
  bool _isLoadingMore = false;
  bool _hasNextPage = true;
  int _loadedPage = 0;
  String? _initialErrorMessage;
  String? _loadMoreErrorMessage;

  MovieReviewSort get sort => _sort;
  List<MovieReviewDto> get items => _items;
  bool get isInitialLoading => _isInitialLoading;
  bool get isLoadingMore => _isLoadingMore;
  bool get hasNextPage => _hasNextPage;
  String? get initialErrorMessage => _initialErrorMessage;
  String? get loadMoreErrorMessage => _loadMoreErrorMessage;

  Future<void> loadInitial() async {
    if (_isInitialLoading) {
      return;
    }

    _isInitialLoading = true;
    _initialErrorMessage = null;
    _loadMoreErrorMessage = null;
    notifyListeners();

    try {
      final reviews = await fetchMovieReviews(
        movieNumber: movieNumber,
        page: 1,
        pageSize: pageSize,
        sort: _sort,
      );
      _items = reviews;
      _loadedPage = 1;
      _hasNextPage = reviews.length >= pageSize;
      _initialErrorMessage = null;
    } catch (error) {
      _items = const <MovieReviewDto>[];
      _loadedPage = 0;
      _hasNextPage = true;
      _initialErrorMessage = apiErrorMessage(error, fallback: '评论加载失败，请稍后重试。');
    } finally {
      _isInitialLoading = false;
      notifyListeners();
    }
  }

  Future<void> setSort(MovieReviewSort nextSort) async {
    if (_sort == nextSort) {
      return;
    }
    _sort = nextSort;
    notifyListeners();
    await loadInitial();
  }

  Future<void> loadMore() async {
    if (_isInitialLoading ||
        _isLoadingMore ||
        !_hasNextPage ||
        _items.isEmpty) {
      return;
    }

    _isLoadingMore = true;
    _loadMoreErrorMessage = null;
    notifyListeners();

    final nextPage = _loadedPage + 1;
    try {
      final reviews = await fetchMovieReviews(
        movieNumber: movieNumber,
        page: nextPage,
        pageSize: pageSize,
        sort: _sort,
      );
      if (reviews.isEmpty) {
        _hasNextPage = false;
      } else {
        _items = <MovieReviewDto>[..._items, ...reviews];
        _loadedPage = nextPage;
        _hasNextPage = reviews.length >= pageSize;
      }
      _loadMoreErrorMessage = null;
    } catch (error) {
      _loadMoreErrorMessage = apiErrorMessage(
        error,
        fallback: '评论加载更多失败，请稍后重试。',
      );
    } finally {
      _isLoadingMore = false;
      notifyListeners();
    }
  }
}
