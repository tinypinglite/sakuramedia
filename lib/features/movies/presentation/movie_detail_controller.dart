import 'package:flutter/foundation.dart';
import 'package:sakuramedia/core/network/api_exception.dart';
import 'package:sakuramedia/features/movies/data/movie_detail_dto.dart';
import 'package:sakuramedia/features/movies/data/movie_list_item_dto.dart';

class MovieDetailController extends ChangeNotifier {
  MovieDetailController({
    required this.movieNumber,
    required this.fetchMovieDetail,
    required this.fetchSimilarMovies,
  });

  final String movieNumber;
  final Future<MovieDetailDto> Function({required String movieNumber})
  fetchMovieDetail;
  final Future<List<MovieListItemDto>> Function({
    required String movieNumber,
    int limit,
  })
  fetchSimilarMovies;

  MovieDetailDto? _movie;
  bool _isLoading = true;
  String? _errorMessage;
  List<MovieListItemDto> _similarMovies = const <MovieListItemDto>[];
  bool _isSimilarMoviesLoading = false;
  String? _similarMoviesErrorMessage;
  _MovieDetailPreview _selectedPreview =
      const _MovieDetailPreview.placeholder();

  MovieDetailDto? get movie => _movie;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  List<MovieListItemDto> get similarMovies => _similarMovies;
  bool get isSimilarMoviesLoading => _isSimilarMoviesLoading;
  String? get similarMoviesErrorMessage => _similarMoviesErrorMessage;
  String? get selectedPreviewUrl => _selectedPreview.url;
  String get selectedPreviewKey => _selectedPreview.key;

  void applyMovie(MovieDetailDto movie, {bool resetPreview = false}) {
    _movie = movie;
    _selectedPreview =
        resetPreview
            ? _defaultPreviewFor(movie)
            : _resolveUpdatedPreview(movie);
    _errorMessage = null;
    notifyListeners();
  }

  Future<void> refresh() async {
    if (_isLoading) {
      return;
    }
    final similarFuture = _loadSimilarMovies();
    final movie = await fetchMovieDetail(movieNumber: movieNumber);
    _movie = movie;
    _selectedPreview = _defaultPreviewFor(movie);
    _errorMessage = null;
    notifyListeners();
    await similarFuture;
  }

  Future<void> load() async {
    _isLoading = true;
    _errorMessage = null;
    _similarMoviesErrorMessage = null;
    _isSimilarMoviesLoading = true;
    _similarMovies = const <MovieListItemDto>[];
    notifyListeners();

    final similarFuture = _loadSimilarMovies(clearExisting: true);

    try {
      final movie = await fetchMovieDetail(movieNumber: movieNumber);
      _movie = movie;
      _selectedPreview = _defaultPreviewFor(movie);
      _errorMessage = null;
    } catch (error) {
      _movie = null;
      _selectedPreview = const _MovieDetailPreview.placeholder();
      _errorMessage = _messageForError(error);
    } finally {
      _isLoading = false;
      notifyListeners();
    }

    await similarFuture;
  }

  Future<void> retryLoadSimilarMovies() {
    return _loadSimilarMovies(clearExisting: false);
  }

  _MovieDetailPreview _defaultPreviewFor(MovieDetailDto movie) {
    final coverUrl = movie.coverImage?.bestAvailableUrl ?? '';
    if (coverUrl.isNotEmpty) {
      return _MovieDetailPreview.cover(url: coverUrl);
    }

    final thinCoverUrl = movie.thinCoverImage?.bestAvailableUrl ?? '';
    if (thinCoverUrl.isNotEmpty) {
      return _MovieDetailPreview.thinCover(url: thinCoverUrl);
    }

    return const _MovieDetailPreview.placeholder();
  }

  _MovieDetailPreview _resolveUpdatedPreview(MovieDetailDto movie) {
    if (_selectedPreview.key == 'cover') {
      final coverUrl = movie.coverImage?.bestAvailableUrl ?? '';
      if (coverUrl.isNotEmpty) {
        return _MovieDetailPreview.cover(url: coverUrl);
      }
    }

    if (_selectedPreview.key == 'thin-cover') {
      final thinCoverUrl = movie.thinCoverImage?.bestAvailableUrl ?? '';
      if (thinCoverUrl.isNotEmpty) {
        return _MovieDetailPreview.thinCover(url: thinCoverUrl);
      }
    }

    return _defaultPreviewFor(movie);
  }

  String _messageForError(Object error) {
    if (error is ApiException &&
        (error.statusCode == 404 || error.error?.code == 'movie_not_found')) {
      return '未找到该影片';
    }
    return '影片详情暂时无法加载，请稍后重试';
  }

  Future<void> _loadSimilarMovies({bool clearExisting = false}) async {
    _isSimilarMoviesLoading = true;
    _similarMoviesErrorMessage = null;
    if (clearExisting) {
      _similarMovies = const <MovieListItemDto>[];
    }
    notifyListeners();

    try {
      final movies = await fetchSimilarMovies(
        movieNumber: movieNumber,
        limit: 15,
      );
      _similarMovies = movies.take(15).toList(growable: false);
      _similarMoviesErrorMessage = null;
    } catch (_) {
      _similarMoviesErrorMessage = '相似影片暂时无法加载，请稍后重试';
    } finally {
      _isSimilarMoviesLoading = false;
      notifyListeners();
    }
  }
}

class _MovieDetailPreview {
  const _MovieDetailPreview({required this.key, required this.url});

  const _MovieDetailPreview.cover({required String url})
    : this(key: 'cover', url: url);

  const _MovieDetailPreview.thinCover({required String url})
    : this(key: 'thin-cover', url: url);

  const _MovieDetailPreview.placeholder() : this(key: 'placeholder', url: null);

  final String key;
  final String? url;
}
