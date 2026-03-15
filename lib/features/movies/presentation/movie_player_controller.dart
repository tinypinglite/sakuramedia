import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:sakuramedia/core/media/media_url_resolver.dart';
import 'package:sakuramedia/core/network/api_exception.dart';
import 'package:sakuramedia/features/movies/data/movie_detail_dto.dart';
import 'package:sakuramedia/features/movies/data/movie_media_thumbnail_dto.dart';

class MoviePlayerController extends ChangeNotifier {
  MoviePlayerController({
    required this.movieNumber,
    required this.baseUrl,
    required this.fetchMovieDetail,
    required this.fetchMediaThumbnails,
    required this.updateMediaProgress,
    this.initialMediaId,
    this.initialPositionSeconds,
    this.progressReportInterval = const Duration(seconds: 5),
  });

  final String movieNumber;
  final String baseUrl;
  final int? initialMediaId;
  final int? initialPositionSeconds;
  final Duration progressReportInterval;
  final Future<MovieDetailDto> Function({required String movieNumber})
  fetchMovieDetail;
  final Future<List<MovieMediaThumbnailDto>> Function({required int mediaId})
  fetchMediaThumbnails;
  final Future<MovieMediaProgressDto> Function({
    required int mediaId,
    required int positionSeconds,
  })
  updateMediaProgress;

  MovieDetailDto? _movie;
  MovieMediaItemDto? _selectedMedia;
  List<MovieMediaThumbnailDto> _thumbnails = const <MovieMediaThumbnailDto>[];
  bool _isLoading = true;
  bool _isThumbnailLoading = false;
  bool _isPlaying = false;
  bool _isThumbnailScrollLocked = true;
  int? _thumbnailColumns;
  bool _hasManualThumbnailColumnOverride = false;
  int _currentPlaybackSeconds = 0;
  int? _activeThumbnailIndex;
  int? _lastReportedPositionSeconds;
  Duration? _startupPlaybackPosition;
  String? _errorMessage;
  String? _thumbnailErrorMessage;
  Timer? _progressTimer;

  MovieDetailDto? get movie => _movie;
  MovieMediaItemDto? get selectedMedia => _selectedMedia;
  List<MovieMediaThumbnailDto> get thumbnails => _thumbnails;
  bool get isLoading => _isLoading;
  bool get isThumbnailLoading => _isThumbnailLoading;
  String? get errorMessage => _errorMessage;
  String? get thumbnailErrorMessage => _thumbnailErrorMessage;
  bool get isThumbnailScrollLocked => _isThumbnailScrollLocked;
  bool get usesAutoThumbnailColumns => !_hasManualThumbnailColumnOverride;
  int? get thumbnailColumns => _thumbnailColumns;
  int get currentPlaybackSeconds => _currentPlaybackSeconds;
  int? get activeThumbnailIndex => _activeThumbnailIndex;

  String? get resolvedPlayUrl =>
      resolveMediaUrl(rawUrl: _selectedMedia?.playUrl, baseUrl: baseUrl);

  Duration? get initialPlaybackPosition => _startupPlaybackPosition;

  Future<void> load() async {
    debugPrint(
      '[player-debug] controller_load_start movie=$movieNumber initialMediaId=$initialMediaId initialPositionSeconds=$initialPositionSeconds',
    );
    _stopProgressTimer();
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final movie = await fetchMovieDetail(movieNumber: movieNumber);
      _movie = movie;
      _selectedMedia = _resolveInitialMedia(movie.mediaItems);
      _thumbnails = const <MovieMediaThumbnailDto>[];
      _thumbnailErrorMessage = null;
      _isThumbnailLoading = false;
      _startupPlaybackPosition = _resolveStartupPlaybackPosition(
        _selectedMedia,
      );
      debugPrint(
        '[player-debug] controller_load_resolved movie=$movieNumber selectedMediaId=${_selectedMedia?.mediaId} hasPlayUrl=${_selectedMedia?.hasPlayableUrl} storedProgress=${_selectedMedia?.progress?.lastPositionSeconds} startupPositionSeconds=${_startupPlaybackPosition?.inSeconds}',
      );
      _currentPlaybackSeconds = _startupPlaybackPosition?.inSeconds ?? 0;
      _lastReportedPositionSeconds = _startupPlaybackPosition?.inSeconds;
      _activeThumbnailIndex = null;
      if (_selectedMedia != null) {
        await loadThumbnails();
      }
      _errorMessage = null;
    } catch (error) {
      debugPrint(
        '[player-debug] controller_load_error movie=$movieNumber error=$error',
      );
      _movie = null;
      _selectedMedia = null;
      _thumbnails = const <MovieMediaThumbnailDto>[];
      _thumbnailErrorMessage = null;
      _isThumbnailLoading = false;
      _startupPlaybackPosition = null;
      _errorMessage = _messageForError(error);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadThumbnails() async {
    final media = _selectedMedia;
    if (media == null) {
      _thumbnails = const <MovieMediaThumbnailDto>[];
      _thumbnailErrorMessage = null;
      _activeThumbnailIndex = null;
      notifyListeners();
      return;
    }

    _isThumbnailLoading = true;
    _thumbnailErrorMessage = null;
    notifyListeners();

    try {
      _thumbnails = await fetchMediaThumbnails(mediaId: media.mediaId);
      _updateActiveThumbnailIndex();
    } catch (_) {
      _thumbnails = const <MovieMediaThumbnailDto>[];
      _thumbnailErrorMessage = '请稍后重试。';
      _activeThumbnailIndex = null;
    } finally {
      _isThumbnailLoading = false;
      notifyListeners();
    }
  }

  void applyAutoThumbnailColumns(int count) {
    if (_hasManualThumbnailColumnOverride || _thumbnailColumns == count) {
      return;
    }
    _thumbnailColumns = count;
    notifyListeners();
  }

  void setThumbnailColumns(int count) {
    _hasManualThumbnailColumnOverride = true;
    if (_thumbnailColumns == count) {
      return;
    }
    _thumbnailColumns = count;
    notifyListeners();
  }

  void toggleThumbnailScrollLock() {
    _isThumbnailScrollLocked = !_isThumbnailScrollLocked;
    notifyListeners();
  }

  void handleThumbnailTap(int index) {
    if (index < 0 || index >= _thumbnails.length) {
      return;
    }
    final nextSeconds = _thumbnails[index].offsetSeconds;
    final needsNotify =
        _currentPlaybackSeconds != nextSeconds ||
        _activeThumbnailIndex != index;
    _currentPlaybackSeconds = nextSeconds;
    _activeThumbnailIndex = index;
    if (needsNotify) {
      notifyListeners();
    }
  }

  void handlePlaybackPosition(Duration position) {
    final nextSeconds = position.inSeconds;
    if (_currentPlaybackSeconds == nextSeconds && _thumbnails.isEmpty) {
      return;
    }
    _currentPlaybackSeconds = nextSeconds;
    _updateActiveThumbnailIndex();
    notifyListeners();
  }

  void handlePlaybackPlayingChanged(bool isPlaying) {
    if (_isPlaying == isPlaying) {
      return;
    }
    _isPlaying = isPlaying;
    if (isPlaying) {
      _startProgressTimer();
    } else {
      _stopProgressTimer();
    }
  }

  Future<void> flushPlaybackProgress() async {
    await _reportProgressIfNeeded();
  }

  MovieMediaItemDto? _resolveInitialMedia(List<MovieMediaItemDto> items) {
    if (initialMediaId != null) {
      for (final item in items) {
        if (item.mediaId == initialMediaId && item.hasPlayableUrl) {
          return item;
        }
      }
    }

    for (final item in items) {
      if (item.hasPlayableUrl) {
        return item;
      }
    }

    return null;
  }

  Duration? _resolveStartupPlaybackPosition(MovieMediaItemDto? media) {
    if (initialPositionSeconds != null && initialPositionSeconds! > 0) {
      debugPrint(
        '[player-debug] startup_position_source=requested requested=$initialPositionSeconds mediaId=${media?.mediaId}',
      );
      return Duration(seconds: initialPositionSeconds!);
    }

    final storedSeconds = media?.progress?.lastPositionSeconds ?? 0;
    if (storedSeconds > 0) {
      debugPrint(
        '[player-debug] startup_position_source=stored stored=$storedSeconds mediaId=${media?.mediaId}',
      );
      return Duration(seconds: storedSeconds);
    }

    debugPrint(
      '[player-debug] startup_position_source=none mediaId=${media?.mediaId}',
    );
    return null;
  }

  void _startProgressTimer() {
    _stopProgressTimer();
    _progressTimer = Timer.periodic(progressReportInterval, (_) {
      unawaited(_reportProgressIfNeeded());
    });
  }

  void _stopProgressTimer() {
    _progressTimer?.cancel();
    _progressTimer = null;
  }

  Future<void> _reportProgressIfNeeded() async {
    final media = _selectedMedia;
    if (media == null) {
      return;
    }
    final positionSeconds = _currentPlaybackSeconds;
    if (positionSeconds <= 0 ||
        _lastReportedPositionSeconds == positionSeconds) {
      return;
    }
    _lastReportedPositionSeconds = positionSeconds;
    try {
      await updateMediaProgress(
        mediaId: media.mediaId,
        positionSeconds: positionSeconds,
      );
    } catch (_) {
      _lastReportedPositionSeconds = null;
    }
  }

  void _updateActiveThumbnailIndex() {
    if (_thumbnails.isEmpty) {
      _activeThumbnailIndex = null;
      return;
    }

    var candidate = 0;
    for (var index = 0; index < _thumbnails.length; index++) {
      if (_thumbnails[index].offsetSeconds <= _currentPlaybackSeconds) {
        candidate = index;
        continue;
      }
      break;
    }
    _activeThumbnailIndex = candidate;
  }

  String _messageForError(Object error) {
    if (error is ApiException &&
        (error.statusCode == 404 || error.error?.code == 'movie_not_found')) {
      return '未找到该影片';
    }
    return '播放器暂时无法加载，请稍后重试';
  }

  @override
  void dispose() {
    _stopProgressTimer();
    super.dispose();
  }
}
