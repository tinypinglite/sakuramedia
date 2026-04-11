import 'package:flutter/foundation.dart';
import 'package:sakuramedia/core/network/api_exception.dart';
import 'package:sakuramedia/features/movies/data/movie_detail_dto.dart';

class MovieDetailController extends ChangeNotifier {
  MovieDetailController({
    required this.movieNumber,
    required this.fetchMovieDetail,
  });

  final String movieNumber;
  final Future<MovieDetailDto> Function({required String movieNumber})
  fetchMovieDetail;

  MovieDetailDto? _movie;
  bool _isLoading = true;
  String? _errorMessage;
  _MovieDetailPreview _selectedPreview =
      const _MovieDetailPreview.placeholder();

  MovieDetailDto? get movie => _movie;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  String? get selectedPreviewUrl => _selectedPreview.url;
  String get selectedPreviewKey => _selectedPreview.key;

  Future<void> refresh() async {
    if (_isLoading) {
      return;
    }
    final movie = await fetchMovieDetail(movieNumber: movieNumber);
    _movie = movie;
    _selectedPreview = _defaultPreviewFor(movie);
    _errorMessage = null;
    notifyListeners();
  }

  Future<void> load() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

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

  String _messageForError(Object error) {
    if (error is ApiException &&
        (error.statusCode == 404 || error.error?.code == 'movie_not_found')) {
      return '未找到该影片';
    }
    return '影片详情暂时无法加载，请稍后重试';
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
