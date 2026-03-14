import 'package:flutter/foundation.dart';
import 'package:sakuramedia/features/movies/data/movie_media_thumbnail_dto.dart';

class MovieDetailThumbnailController extends ChangeNotifier {
  MovieDetailThumbnailController({
    required this.mediaId,
    required this.fetchMediaThumbnails,
  });

  final int? mediaId;
  final Future<List<MovieMediaThumbnailDto>> Function({required int mediaId})
  fetchMediaThumbnails;

  List<MovieMediaThumbnailDto> _thumbnails = const <MovieMediaThumbnailDto>[];
  bool _isLoading = false;
  bool _hasLoaded = false;
  int? _columns;
  bool _hasManualColumnOverride = false;
  int? _activeIndex;
  String? _errorMessage;

  List<MovieMediaThumbnailDto> get thumbnails => _thumbnails;
  bool get isLoading => _isLoading;
  bool get hasLoaded => _hasLoaded;
  bool get usesAutoColumns => !_hasManualColumnOverride;
  int? get columns => _columns;
  int? get activeIndex => _activeIndex;
  String? get errorMessage => _errorMessage;

  Future<void> loadIfNeeded() async {
    if (_hasLoaded || _isLoading) {
      return;
    }
    await _load();
  }

  Future<void> retry() async {
    if (_isLoading) {
      return;
    }
    await _load();
  }

  void applyAutoColumns(int columns) {
    if (_hasManualColumnOverride || _columns == columns) {
      return;
    }
    _columns = columns;
    notifyListeners();
  }

  void setColumns(int columns) {
    _hasManualColumnOverride = true;
    if (_columns == columns) {
      return;
    }
    _columns = columns;
    notifyListeners();
  }

  void selectIndex(int index) {
    if (index < 0 || index >= _thumbnails.length || _activeIndex == index) {
      return;
    }
    _activeIndex = index;
    notifyListeners();
  }

  Future<void> _load() async {
    if (mediaId == null) {
      _thumbnails = const <MovieMediaThumbnailDto>[];
      _errorMessage = null;
      _activeIndex = null;
      _hasLoaded = true;
      notifyListeners();
      return;
    }

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _thumbnails = await fetchMediaThumbnails(mediaId: mediaId!);
      _errorMessage = null;
      _activeIndex = _thumbnails.isEmpty ? null : 0;
    } catch (_) {
      _thumbnails = const <MovieMediaThumbnailDto>[];
      _errorMessage = '请稍后重试。';
      _activeIndex = null;
    } finally {
      _isLoading = false;
      _hasLoaded = true;
      notifyListeners();
    }
  }
}
