import 'package:flutter/foundation.dart';
import 'package:sakuramedia/core/network/api_exception.dart';
import 'package:sakuramedia/features/configuration/data/dto/media_library_dto.dart';
import 'package:sakuramedia/features/media/data/media_storage_descriptor.dart';
import 'package:sakuramedia/features/movies/data/dto/detail/movie_detail_dto.dart';
import 'package:sakuramedia/features/movies/data/dto/listing/movie_list_item_dto.dart';
import 'package:sakuramedia/features/shared/presentation/dispose_safe_notifier.dart';

class MovieDetailController extends ChangeNotifier with DisposeSafeNotifier {
  MovieDetailController({
    required this.movieNumber,
    required this.fetchMovieDetail,
    required this.fetchSimilarMovies,
    this.fetchMediaLibraries,
  });

  final String movieNumber;
  final Future<MovieDetailDto> Function({required String movieNumber})
  fetchMovieDetail;
  final Future<List<MovieListItemDto>> Function({
    required String movieNumber,
    int limit,
  })
  fetchSimilarMovies;
  final Future<List<MediaLibraryDto>> Function()? fetchMediaLibraries;

  MovieDetailDto? _movie;
  bool _isLoading = true;
  String? _errorMessage;
  List<MovieListItemDto> _similarMovies = const <MovieListItemDto>[];
  Map<int, MediaStorageDescriptor> _storageDescriptors =
      const <int, MediaStorageDescriptor>{};
  bool _isSimilarMoviesLoading = false;
  String? _similarMoviesErrorMessage;
  _MovieDetailPreview _selectedPreview =
      const _MovieDetailPreview.placeholder();

  MovieDetailDto? get movie => _movie;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  List<MovieListItemDto> get similarMovies => _similarMovies;
  Map<int, MediaStorageDescriptor> get storageDescriptors =>
      _storageDescriptors;
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
    notifyListenersSafely();
  }

  Future<void> refresh() async {
    if (_isLoading) {
      return;
    }
    final similarFuture = _loadSimilarMovies();
    final results = await Future.wait<Object>(<Future<Object>>[
      fetchMovieDetail(movieNumber: movieNumber),
      _fetchStorageDescriptors(),
    ]);
    final movie = results[0] as MovieDetailDto;
    _storageDescriptors = results[1] as Map<int, MediaStorageDescriptor>;
    _movie = movie;
    _selectedPreview = _defaultPreviewFor(movie);
    _errorMessage = null;
    notifyListenersSafely();
    await similarFuture;
  }

  Future<void> load() async {
    _isLoading = true;
    _errorMessage = null;
    _similarMoviesErrorMessage = null;
    _isSimilarMoviesLoading = true;
    _similarMovies = const <MovieListItemDto>[];
    notifyListenersSafely();

    final similarFuture = _loadSimilarMovies(clearExisting: true);

    try {
      final results = await Future.wait<Object>(<Future<Object>>[
        fetchMovieDetail(movieNumber: movieNumber),
        _fetchStorageDescriptors(),
      ]);
      final movie = results[0] as MovieDetailDto;
      _storageDescriptors = results[1] as Map<int, MediaStorageDescriptor>;
      _movie = movie;
      _selectedPreview = _defaultPreviewFor(movie);
      _errorMessage = null;
    } catch (error) {
      _movie = null;
      _storageDescriptors = const <int, MediaStorageDescriptor>{};
      _selectedPreview = const _MovieDetailPreview.placeholder();
      _errorMessage = _messageForError(error);
    } finally {
      _isLoading = false;
      notifyListenersSafely();
    }

    await similarFuture;
  }

  Future<Map<int, MediaStorageDescriptor>> _fetchStorageDescriptors() async {
    final fetch = fetchMediaLibraries;
    if (fetch == null) {
      return const <int, MediaStorageDescriptor>{};
    }
    try {
      return buildMediaStorageDescriptors(await fetch());
    } catch (_) {
      return const <int, MediaStorageDescriptor>{};
    }
  }

  Future<void> retryLoadSimilarMovies() {
    return _loadSimilarMovies(clearExisting: false);
  }

  _MovieDetailPreview _defaultPreviewFor(MovieDetailDto movie) {
    final coverUrl = movie.coverImage?.bestAvailableUrl ?? '';
    if (coverUrl.isNotEmpty) {
      return _MovieDetailPreview.cover(url: coverUrl);
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
    notifyListenersSafely();

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
      notifyListenersSafely();
    }
  }
}

class _MovieDetailPreview {
  const _MovieDetailPreview({required this.key, required this.url});

  const _MovieDetailPreview.cover({required String url})
    : this(key: 'cover', url: url);

  const _MovieDetailPreview.placeholder() : this(key: 'placeholder', url: null);

  final String key;
  final String? url;
}
