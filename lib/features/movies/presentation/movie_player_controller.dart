import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:sakuramedia/core/media/media_url_resolver.dart';
import 'package:sakuramedia/core/network/api_exception.dart';
import 'package:sakuramedia/features/movies/data/movie_detail_dto.dart';
import 'package:sakuramedia/features/movies/data/movie_media_thumbnail_dto.dart';
import 'package:sakuramedia/features/movies/data/movie_subtitle_dto.dart';
import 'package:sakuramedia/features/movies/presentation/movie_player_subtitle_state.dart';

class MoviePlayerController extends ChangeNotifier {
  MoviePlayerController({
    required this.movieNumber,
    required this.baseUrl,
    required this.fetchMovieDetail,
    required this.fetchMediaThumbnails,
    required this.fetchMovieSubtitles,
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
  final Future<MovieSubtitleListDto> Function({required String movieNumber})
  fetchMovieSubtitles;
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
  bool _isSubtitleLoading = false;
  bool _isPlaying = false;
  bool _isThumbnailScrollLocked = true;
  int? _thumbnailColumns;
  bool _hasManualThumbnailColumnOverride = false;
  int _currentPlaybackSeconds = 0;
  final ValueNotifier<int?> _activeThumbnailIndexNotifier = ValueNotifier<int?>(
    null,
  );
  int? _lastReportedPositionSeconds;
  Duration? _startupPlaybackPosition;
  String? _errorMessage;
  String? _thumbnailErrorMessage;
  String? _subtitleErrorMessage;
  String _subtitleFetchStatus = 'pending';
  List<MoviePlayerSubtitleOption> _subtitleOptions =
      const <MoviePlayerSubtitleOption>[];
  int? _selectedSubtitleId;
  Timer? _progressTimer;

  MovieDetailDto? get movie => _movie;
  MovieMediaItemDto? get selectedMedia => _selectedMedia;
  List<MovieMediaThumbnailDto> get thumbnails => _thumbnails;
  bool get isLoading => _isLoading;
  bool get isThumbnailLoading => _isThumbnailLoading;
  bool get isSubtitleLoading => _isSubtitleLoading;
  String? get errorMessage => _errorMessage;
  String? get thumbnailErrorMessage => _thumbnailErrorMessage;
  String? get subtitleErrorMessage => _subtitleErrorMessage;
  String get subtitleFetchStatus => _subtitleFetchStatus;
  bool get isThumbnailScrollLocked => _isThumbnailScrollLocked;
  bool get usesAutoThumbnailColumns => !_hasManualThumbnailColumnOverride;
  int? get thumbnailColumns => _thumbnailColumns;
  int get currentPlaybackSeconds => _currentPlaybackSeconds;
  int? get activeThumbnailIndex => _activeThumbnailIndexNotifier.value;
  List<MoviePlayerSubtitleOption> get subtitleOptions => _subtitleOptions;
  int? get selectedSubtitleId => _selectedSubtitleId;
  ValueListenable<int?> get activeThumbnailIndexListenable =>
      _activeThumbnailIndexNotifier;

  MoviePlayerSubtitleState get subtitleState => MoviePlayerSubtitleState(
    options: _subtitleOptions,
    selectedSubtitleId: _selectedSubtitleId,
    isLoading: _isSubtitleLoading,
    fetchStatus: _subtitleFetchStatus,
    errorMessage: _subtitleErrorMessage,
  );

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
      _resetSubtitleState();
      _startupPlaybackPosition = _resolveStartupPlaybackPosition(
        _selectedMedia,
      );
      debugPrint(
        '[player-debug] controller_load_resolved movie=$movieNumber selectedMediaId=${_selectedMedia?.mediaId} hasPlayUrl=${_selectedMedia?.hasPlayableUrl} storedProgress=${_selectedMedia?.progress?.lastPositionSeconds} startupPositionSeconds=${_startupPlaybackPosition?.inSeconds}',
      );
      _currentPlaybackSeconds = _startupPlaybackPosition?.inSeconds ?? 0;
      _lastReportedPositionSeconds = _startupPlaybackPosition?.inSeconds;
      _setActiveThumbnailIndex(null);
      await Future.wait<void>(<Future<void>>[
        if (_selectedMedia != null) loadThumbnails(),
        loadSubtitles(),
      ]);
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
      _resetSubtitleState();
      _startupPlaybackPosition = null;
      _setActiveThumbnailIndex(null);
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
      _setActiveThumbnailIndex(null);
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
      _setActiveThumbnailIndex(null);
    } finally {
      _isThumbnailLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadSubtitles() async {
    final previousSelectedSubtitleId = _selectedSubtitleId;
    debugPrint(
      '[player-debug] subtitle_state_load_begin movie=$movieNumber previousSelected=$previousSelectedSubtitleId',
    );
    _isSubtitleLoading = true;
    _subtitleErrorMessage = null;
    notifyListeners();

    try {
      final result = await fetchMovieSubtitles(movieNumber: movieNumber);
      _subtitleFetchStatus =
          result.fetchStatus.trim().isEmpty
              ? 'pending'
              : result.fetchStatus.trim();
      _subtitleOptions = result.items
          .map(_buildSubtitleOption)
          .whereType<MoviePlayerSubtitleOption>()
          .toList(growable: false);
      _selectedSubtitleId =
          _subtitleOptions.any(
                (item) => item.subtitleId == previousSelectedSubtitleId,
              )
              ? previousSelectedSubtitleId
              : null;
      _subtitleErrorMessage = _subtitleErrorMessageFromResult(result);
      debugPrint(
        '[player-debug] subtitle_state_load_success movie=$movieNumber fetchStatus=$_subtitleFetchStatus selected=$_selectedSubtitleId error=$_subtitleErrorMessage options=${_subtitleOptions.map((item) => "${item.subtitleId}:${item.label}").join("|")}',
      );
    } catch (_) {
      _subtitleFetchStatus = 'failed';
      _subtitleOptions = const <MoviePlayerSubtitleOption>[];
      _selectedSubtitleId = null;
      _subtitleErrorMessage = '请稍后重试。';
      debugPrint(
        '[player-debug] subtitle_state_load_error movie=$movieNumber selected=$_selectedSubtitleId',
      );
    } finally {
      _isSubtitleLoading = false;
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

  void setSelectedSubtitleId(int? subtitleId) {
    if (subtitleId != null &&
        !_subtitleOptions.any((item) => item.subtitleId == subtitleId)) {
      debugPrint(
        '[player-debug] subtitle_state_set_ignored reason=unknown_id requested=$subtitleId options=${_subtitleOptions.map((item) => item.subtitleId).join(",")}',
      );
      return;
    }
    if (_selectedSubtitleId == subtitleId) {
      debugPrint(
        '[player-debug] subtitle_state_set_ignored reason=unchanged requested=$subtitleId',
      );
      return;
    }
    debugPrint(
      '[player-debug] subtitle_state_set from=$_selectedSubtitleId to=$subtitleId',
    );
    _selectedSubtitleId = subtitleId;
    notifyListeners();
  }

  void handleThumbnailTap(int index) {
    if (index < 0 || index >= _thumbnails.length) {
      return;
    }
    final nextSeconds = _thumbnails[index].offsetSeconds;
    _currentPlaybackSeconds = nextSeconds;
    _setActiveThumbnailIndex(index);
  }

  void handlePlaybackPosition(Duration position) {
    final nextSeconds = position.inSeconds;
    if (_currentPlaybackSeconds == nextSeconds) {
      return;
    }
    _currentPlaybackSeconds = nextSeconds;
    _updateActiveThumbnailIndex();
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

  MoviePlayerSubtitleOption? _buildSubtitleOption(MovieSubtitleItemDto item) {
    final resolvedUrl = resolveMediaUrl(rawUrl: item.url, baseUrl: baseUrl);
    if (resolvedUrl == null || resolvedUrl.isEmpty) {
      return null;
    }
    final label =
        item.fileName.trim().isNotEmpty
            ? item.fileName.trim()
            : '字幕 ${item.subtitleId}';
    return MoviePlayerSubtitleOption(
      subtitleId: item.subtitleId,
      label: label,
      resolvedUrl: resolvedUrl,
      title: label,
    );
  }

  String? _subtitleErrorMessageFromResult(MovieSubtitleListDto result) {
    final lastError = result.lastError?.trim();
    if (lastError != null && lastError.isNotEmpty) {
      return lastError;
    }
    if (result.fetchStatus == 'failed') {
      return '字幕抓取失败';
    }
    return null;
  }

  void _resetSubtitleState() {
    _isSubtitleLoading = false;
    _subtitleErrorMessage = null;
    _subtitleFetchStatus = 'pending';
    _subtitleOptions = const <MoviePlayerSubtitleOption>[];
    _selectedSubtitleId = null;
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
      _setActiveThumbnailIndex(null);
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
    _setActiveThumbnailIndex(candidate);
  }

  void _setActiveThumbnailIndex(int? index) {
    if (_activeThumbnailIndexNotifier.value == index) {
      return;
    }
    _activeThumbnailIndexNotifier.value = index;
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
    _activeThumbnailIndexNotifier.dispose();
    super.dispose();
  }
}
