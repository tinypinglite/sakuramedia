import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:sakuramedia/features/movies/data/movie_media_thumbnail_dto.dart';

class MovieDetailThumbnailController extends ChangeNotifier {
  static const int defaultIntervalSeconds = 10;

  MovieDetailThumbnailController({
    required this.mediaId,
    required this.fetchMediaThumbnails,
  });

  final int? mediaId;
  final Future<List<MovieMediaThumbnailDto>> Function({required int mediaId})
  fetchMediaThumbnails;

  List<MovieMediaThumbnailDto> _allThumbnails =
      const <MovieMediaThumbnailDto>[];
  List<MovieMediaThumbnailDto> _thumbnails = const <MovieMediaThumbnailDto>[];
  bool _isLoading = false;
  bool _hasLoaded = false;
  int? _columns;
  bool _hasManualColumnOverride = false;
  int? _activeIndex;
  String? _errorMessage;
  int _selectedIntervalSeconds = defaultIntervalSeconds;

  List<MovieMediaThumbnailDto> get thumbnails => _thumbnails;
  bool get isLoading => _isLoading;
  bool get hasLoaded => _hasLoaded;
  bool get usesAutoColumns => !_hasManualColumnOverride;
  int? get columns => _columns;
  int? get activeIndex => _activeIndex;
  String? get errorMessage => _errorMessage;
  int get selectedIntervalSeconds => _selectedIntervalSeconds;

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

  void setIntervalSeconds(int seconds) {
    if (_selectedIntervalSeconds == seconds) {
      return;
    }
    final preservedThumbnailId = _selectedThumbnailId;
    _selectedIntervalSeconds = seconds;
    _rebuildFilteredThumbnails(preservedThumbnailId: preservedThumbnailId);
    notifyListeners();
  }

  Future<void> _load() async {
    if (mediaId == null) {
      _allThumbnails = const <MovieMediaThumbnailDto>[];
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
      _allThumbnails = await fetchMediaThumbnails(mediaId: mediaId!);
      _rebuildFilteredThumbnails();
      _errorMessage = null;
    } catch (_) {
      _allThumbnails = const <MovieMediaThumbnailDto>[];
      _thumbnails = const <MovieMediaThumbnailDto>[];
      _errorMessage = '请稍后重试。';
      _activeIndex = null;
    } finally {
      _isLoading = false;
      _hasLoaded = true;
      notifyListeners();
    }
  }

  int? get _selectedThumbnailId {
    final activeIndex = _activeIndex;
    if (activeIndex == null ||
        activeIndex < 0 ||
        activeIndex >= _thumbnails.length) {
      return null;
    }
    return _thumbnails[activeIndex].thumbnailId;
  }

  void _rebuildFilteredThumbnails({int? preservedThumbnailId}) {
    _thumbnails = _filterThumbnails(_allThumbnails);
    if (_thumbnails.isEmpty) {
      _activeIndex = null;
      return;
    }

    if (preservedThumbnailId != null) {
      final preservedIndex = _thumbnails.indexWhere(
        (thumbnail) => thumbnail.thumbnailId == preservedThumbnailId,
      );
      if (preservedIndex >= 0) {
        _activeIndex = preservedIndex;
        return;
      }
    }

    _activeIndex = 0;
  }

  List<MovieMediaThumbnailDto> _filterThumbnails(
    List<MovieMediaThumbnailDto> thumbnails,
  ) {
    if (thumbnails.length < 2) {
      return thumbnails;
    }

    final stepSeconds = _resolveSourceFrameStepSeconds(thumbnails);
    final stride = math.max(1, _selectedIntervalSeconds ~/ stepSeconds);
    if (stride <= 1) {
      return thumbnails;
    }

    return List<MovieMediaThumbnailDto>.generate(
      (thumbnails.length / stride).ceil(),
      (index) => thumbnails[index * stride],
      growable: false,
    );
  }

  int _resolveSourceFrameStepSeconds(List<MovieMediaThumbnailDto> thumbnails) {
    if (thumbnails.length < 2) {
      return defaultIntervalSeconds;
    }

    final offsets = thumbnails
      .map((thumbnail) => thumbnail.offsetSeconds)
      .toList(growable: false)..sort();
    int? minPositiveDiff;
    for (var index = 1; index < offsets.length; index++) {
      final diff = offsets[index] - offsets[index - 1];
      if (diff <= 0) {
        continue;
      }
      minPositiveDiff =
          minPositiveDiff == null ? diff : math.min(minPositiveDiff, diff);
    }
    return minPositiveDiff ?? defaultIntervalSeconds;
  }
}
