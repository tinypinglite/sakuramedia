import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:sakuramedia/core/media/media_url_resolver.dart';
import 'package:sakuramedia/core/media/playback_resume_policy.dart';
import 'package:sakuramedia/core/network/api_exception.dart';
import 'package:sakuramedia/features/configuration/data/dto/media_library_dto.dart';
import 'package:sakuramedia/features/media/data/media_storage_descriptor.dart';
import 'package:sakuramedia/features/media/presentation/providers/media_api_provider.dart';
import 'package:sakuramedia/features/movies/data/dto/detail/movie_detail_dto.dart';
import 'package:sakuramedia/features/movies/data/dto/player/movie_subtitle_dto.dart';
import 'package:sakuramedia/features/movies/data/dto/thumbnails/movie_media_thumbnail_dto.dart';
import 'package:sakuramedia/features/movies/presentation/controllers/player/movie_player_subtitle_state.dart';
import 'package:sakuramedia/features/movies/presentation/providers/movie_player_scope.dart';
import 'package:sakuramedia/features/movies/presentation/providers/movie_player_state.dart';
import 'package:sakuramedia/features/movies/presentation/providers/movies_api_provider.dart';

part 'movie_player_provider.g.dart';

typedef FetchMovieDetail =
    Future<MovieDetailDto> Function({required String movieNumber});
typedef FetchMediaThumbnails =
    Future<List<MovieMediaThumbnailDto>> Function({required int mediaId});
typedef FetchMovieSubtitles =
    Future<MovieSubtitleListDto> Function({required String movieNumber});
typedef UpdateMediaProgress =
    Future<MovieMediaProgressDto> Function({
      required int mediaId,
      required int positionSeconds,
    });
typedef FetchMediaLibraries = Future<List<MediaLibraryDto>> Function();

@immutable
class MoviePlayerDependencies {
  const MoviePlayerDependencies({
    required this.fetchMovieDetail,
    required this.fetchMediaThumbnails,
    required this.fetchMovieSubtitles,
    required this.updateMediaProgress,
    this.fetchMediaLibraries,
  });

  final FetchMovieDetail fetchMovieDetail;
  final FetchMediaThumbnails fetchMediaThumbnails;
  final FetchMovieSubtitles? fetchMovieSubtitles;
  final UpdateMediaProgress updateMediaProgress;
  final FetchMediaLibraries? fetchMediaLibraries;
}

/// 生产依赖装配与播放器状态机解耦，测试可直接 override 这一层。
@Riverpod(keepAlive: true)
MoviePlayerDependencies moviePlayerDependencies(Ref ref) {
  final moviesApi = ref.watch(moviesApiProvider);
  final mediaLibrariesApi = ref.watch(mediaLibrariesApiProvider);
  return MoviePlayerDependencies(
    fetchMovieDetail: moviesApi.getMovieDetail,
    fetchMediaThumbnails: moviesApi.getMediaThumbnails,
    fetchMovieSubtitles: moviesApi.getMovieSubtitles,
    updateMediaProgress: moviesApi.updateMediaProgress,
    fetchMediaLibraries: mediaLibrariesApi.getLibraries,
  );
}

/// 单个播放器路由的业务状态；页面离开后自动销毁并停止定时上报。
@riverpod
class MoviePlayer extends _$MoviePlayer {
  late MoviePlayerDependencies _dependencies;
  final ValueNotifier<int?> _activeThumbnailIndexNotifier = ValueNotifier<int?>(
    null,
  );
  Timer? _progressTimer;
  bool _isPlaying = false;
  bool _isDisposed = false;
  int _loadVersion = 0;
  int _thumbnailVersion = 0;
  int _subtitleVersion = 0;
  int _currentPlaybackSeconds = 0;
  int? _lastReportedPositionSeconds;

  @override
  MoviePlayerState build(MoviePlayerScope scope) {
    _dependencies = ref.read(moviePlayerDependenciesProvider);
    ref.onDispose(_disposeResources);
    return MoviePlayerState();
  }

  int get currentPlaybackSeconds => _currentPlaybackSeconds;
  int? get activeThumbnailIndex => _activeThumbnailIndexNotifier.value;
  ValueListenable<int?> get activeThumbnailIndexListenable =>
      _activeThumbnailIndexNotifier;

  Future<void> load() async {
    final requestVersion = ++_loadVersion;
    _thumbnailVersion += 1;
    _subtitleVersion += 1;
    _stopProgressTimer();
    state = state.copyWith(
      isLoading: true,
      errorMessage: null,
      isResumeDecisionPending: false,
      resumePlaybackPosition: null,
    );

    debugPrint(
      '[player-debug] provider_load_start movie=${scope.movieNumber} initialMediaId=${scope.initialMediaId} initialPositionSeconds=${scope.initialPositionSeconds}',
    );
    try {
      final results = await Future.wait<Object>(<Future<Object>>[
        _dependencies.fetchMovieDetail(movieNumber: scope.movieNumber),
        _fetchStorageDescriptors(),
      ]);
      if (!_isCurrentLoad(requestVersion)) {
        return;
      }
      final movie = results[0] as MovieDetailDto;
      final selectedMedia = _resolveInitialMedia(movie.mediaItems);
      final startupPosition = _resolveExplicitStartupPlaybackPosition();
      final resumePosition = startupPosition == null
          ? _resolveResumePlaybackPosition(selectedMedia)
          : null;
      state = _resetSubtitleState(
        state.copyWith(
          movie: movie,
          selectedMedia: selectedMedia,
          storageDescriptors: results[1] as Map<int, MediaStorageDescriptor>,
          thumbnails: const <MovieMediaThumbnailDto>[],
          thumbnailErrorMessage: null,
          isThumbnailLoading: false,
          startupPlaybackPosition: startupPosition,
          resumePlaybackPosition: resumePosition,
          isResumeDecisionPending: resumePosition != null,
          clipStartIndex: null,
          clipEndIndex: null,
        ),
      );
      _currentPlaybackSeconds = startupPosition?.inSeconds ?? 0;
      _lastReportedPositionSeconds = startupPosition?.inSeconds;
      _setActiveThumbnailIndex(null);
      await Future.wait<void>(<Future<void>>[
        if (selectedMedia != null) loadThumbnails(),
        loadSubtitles(),
      ]);
      if (_isCurrentLoad(requestVersion)) {
        state = state.copyWith(errorMessage: null);
      }
    } catch (error) {
      if (!_isCurrentLoad(requestVersion)) {
        return;
      }
      state = _resetSubtitleState(
        state.copyWith(
          movie: null,
          selectedMedia: null,
          storageDescriptors: const <int, MediaStorageDescriptor>{},
          thumbnails: const <MovieMediaThumbnailDto>[],
          thumbnailErrorMessage: null,
          isThumbnailLoading: false,
          startupPlaybackPosition: null,
          resumePlaybackPosition: null,
          isResumeDecisionPending: false,
          errorMessage: _messageForError(error),
        ),
      );
      _setActiveThumbnailIndex(null);
    } finally {
      if (_isCurrentLoad(requestVersion)) {
        state = state.copyWith(isLoading: false);
      }
    }
  }

  Future<Map<int, MediaStorageDescriptor>> _fetchStorageDescriptors() async {
    final fetch = _dependencies.fetchMediaLibraries;
    if (fetch == null) {
      return const <int, MediaStorageDescriptor>{};
    }
    try {
      return buildMediaStorageDescriptors(await fetch());
    } catch (_) {
      return const <int, MediaStorageDescriptor>{};
    }
  }

  Future<void> loadThumbnails() async {
    final media = state.selectedMedia;
    if (media == null) {
      state = state.copyWith(
        thumbnails: const <MovieMediaThumbnailDto>[],
        thumbnailErrorMessage: null,
      );
      _setActiveThumbnailIndex(null);
      return;
    }
    final requestVersion = ++_thumbnailVersion;
    state = state.copyWith(
      isThumbnailLoading: true,
      thumbnailErrorMessage: null,
      clipStartIndex: null,
      clipEndIndex: null,
    );
    try {
      final thumbnails = await _dependencies.fetchMediaThumbnails(
        mediaId: media.mediaId,
      );
      if (!_isCurrentThumbnail(requestVersion, media.mediaId)) {
        return;
      }
      state = state.copyWith(thumbnails: thumbnails);
      _updateActiveThumbnailIndex();
    } catch (_) {
      if (!_isCurrentThumbnail(requestVersion, media.mediaId)) {
        return;
      }
      state = state.copyWith(
        thumbnails: const <MovieMediaThumbnailDto>[],
        thumbnailErrorMessage: '请稍后重试。',
      );
      _setActiveThumbnailIndex(null);
    } finally {
      if (_isCurrentThumbnail(requestVersion, media.mediaId)) {
        state = state.copyWith(isThumbnailLoading: false);
      }
    }
  }

  Future<void> loadSubtitles() async {
    final fetch = _dependencies.fetchMovieSubtitles;
    if (fetch == null) {
      state = _resetSubtitleState(
        state,
      ).copyWith(subtitleFetchStatus: 'unsupported');
      return;
    }
    final requestVersion = ++_subtitleVersion;
    final previousSelectedSubtitleId = state.selectedSubtitleId;
    state = state.copyWith(isSubtitleLoading: true, subtitleErrorMessage: null);
    try {
      final result = await fetch(movieNumber: scope.movieNumber);
      if (!_isCurrentSubtitle(requestVersion)) {
        return;
      }
      final options = result.items
          .map(_buildSubtitleOption)
          .whereType<MoviePlayerSubtitleOption>()
          .toList(growable: false);
      state = state.copyWith(
        subtitleFetchStatus: result.fetchStatus.trim().isEmpty
            ? 'pending'
            : result.fetchStatus.trim(),
        subtitleOptions: options,
        selectedSubtitleId:
            options.any((item) => item.subtitleId == previousSelectedSubtitleId)
            ? previousSelectedSubtitleId
            : null,
        subtitleErrorMessage: _subtitleErrorMessageFromResult(result),
      );
    } catch (_) {
      if (!_isCurrentSubtitle(requestVersion)) {
        return;
      }
      state = state.copyWith(
        subtitleFetchStatus: 'failed',
        subtitleOptions: const <MoviePlayerSubtitleOption>[],
        selectedSubtitleId: null,
        subtitleErrorMessage: '请稍后重试。',
      );
    } finally {
      if (_isCurrentSubtitle(requestVersion)) {
        state = state.copyWith(isSubtitleLoading: false);
      }
    }
  }

  void applyAutoThumbnailColumns(int count) {
    if (state.hasManualThumbnailColumnOverride ||
        state.thumbnailColumns == count) {
      return;
    }
    state = state.copyWith(thumbnailColumns: count);
  }

  void setThumbnailColumns(int count) {
    if (state.thumbnailColumns == count &&
        state.hasManualThumbnailColumnOverride) {
      return;
    }
    state = state.copyWith(
      thumbnailColumns: count,
      hasManualThumbnailColumnOverride: true,
    );
  }

  void toggleThumbnailScrollLock() {
    state = state.copyWith(
      isThumbnailScrollLocked: !state.isThumbnailScrollLocked,
    );
  }

  void toggleClipSelectionMode() {
    final entering = !state.clipSelectionMode;
    state = state.copyWith(
      clipSelectionMode: entering,
      clipStartIndex: null,
      clipEndIndex: null,
      isThumbnailScrollLocked: entering ? false : state.isThumbnailScrollLocked,
    );
  }

  void handleClipSelectionTap(int index) {
    if (index < 0 || index >= state.thumbnails.length) {
      return;
    }
    if (state.clipStartIndex == null) {
      state = state.copyWith(clipStartIndex: index, clipEndIndex: null);
    } else if (state.clipEndIndex == null) {
      if (index == state.clipStartIndex) {
        return;
      }
      state = state.copyWith(clipEndIndex: index);
    } else {
      state = state.copyWith(clipStartIndex: index, clipEndIndex: null);
    }
  }

  void clearClipSelection() {
    if (state.clipStartIndex == null && state.clipEndIndex == null) {
      return;
    }
    state = state.copyWith(clipStartIndex: null, clipEndIndex: null);
  }

  void setSelectedSubtitleId(int? subtitleId) {
    if (subtitleId != null &&
        !state.subtitleOptions.any((item) => item.subtitleId == subtitleId)) {
      return;
    }
    if (state.selectedSubtitleId == subtitleId) {
      return;
    }
    state = state.copyWith(selectedSubtitleId: subtitleId);
  }

  void handleThumbnailTap(int index) {
    if (index < 0 || index >= state.thumbnails.length) {
      return;
    }
    _currentPlaybackSeconds = state.thumbnails[index].offsetSeconds;
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

  void resolveResumePrompt() {
    if (!state.isResumeDecisionPending) {
      return;
    }
    state = state.copyWith(
      isResumeDecisionPending: false,
      resumePlaybackPosition: null,
    );
  }

  Future<void> flushPlaybackProgress() => _reportProgressIfNeeded();

  MovieMediaItemDto? _resolveInitialMedia(List<MovieMediaItemDto> items) {
    final initialMediaId = scope.initialMediaId;
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

  Duration? _resolveExplicitStartupPlaybackPosition() {
    final initialPositionSeconds = scope.initialPositionSeconds;
    if (initialPositionSeconds != null && initialPositionSeconds > 0) {
      return Duration(seconds: initialPositionSeconds);
    }
    return null;
  }

  Duration? _resolveResumePlaybackPosition(MovieMediaItemDto? media) {
    return resolvePlaybackResumePosition(
      storedPositionSeconds: media?.progress?.lastPositionSeconds ?? 0,
      durationSeconds: media?.durationSeconds ?? 0,
    );
  }

  MoviePlayerSubtitleOption? _buildSubtitleOption(MovieSubtitleItemDto item) {
    final resolvedUrl = resolveMediaUrl(
      rawUrl: item.url,
      baseUrl: scope.baseUrl,
    );
    if (resolvedUrl == null || resolvedUrl.isEmpty) {
      return null;
    }
    final label = item.displayName;
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
    return result.fetchStatus == 'failed' ? '字幕抓取失败' : null;
  }

  MoviePlayerState _resetSubtitleState(MoviePlayerState current) {
    return current.copyWith(
      isSubtitleLoading: false,
      subtitleErrorMessage: null,
      subtitleFetchStatus: 'pending',
      subtitleOptions: const <MoviePlayerSubtitleOption>[],
      selectedSubtitleId: null,
    );
  }

  void _startProgressTimer() {
    _stopProgressTimer();
    _progressTimer = Timer.periodic(scope.progressReportInterval, (_) {
      unawaited(_reportProgressIfNeeded());
    });
  }

  void _stopProgressTimer() {
    _progressTimer?.cancel();
    _progressTimer = null;
  }

  Future<void> _reportProgressIfNeeded() async {
    final media = state.selectedMedia;
    if (media == null || state.isResumeDecisionPending) {
      return;
    }
    final positionSeconds = _currentPlaybackSeconds;
    if (positionSeconds <= 0 ||
        _lastReportedPositionSeconds == positionSeconds) {
      return;
    }
    _lastReportedPositionSeconds = positionSeconds;
    try {
      await _dependencies.updateMediaProgress(
        mediaId: media.mediaId,
        positionSeconds: positionSeconds,
      );
    } catch (_) {
      _lastReportedPositionSeconds = null;
    }
  }

  void _updateActiveThumbnailIndex() {
    final thumbnails = state.thumbnails;
    if (thumbnails.isEmpty) {
      _setActiveThumbnailIndex(null);
      return;
    }
    var candidate = 0;
    for (var index = 0; index < thumbnails.length; index++) {
      if (thumbnails[index].offsetSeconds <= _currentPlaybackSeconds) {
        candidate = index;
        continue;
      }
      break;
    }
    _setActiveThumbnailIndex(candidate);
  }

  void _setActiveThumbnailIndex(int? index) {
    if (_activeThumbnailIndexNotifier.value != index) {
      _activeThumbnailIndexNotifier.value = index;
    }
  }

  String _messageForError(Object error) {
    if (error is ApiException &&
        (error.statusCode == 404 || error.error?.code == 'movie_not_found')) {
      return '未找到该影片';
    }
    return '播放器暂时无法加载，请稍后重试';
  }

  bool _isCurrentLoad(int requestVersion) =>
      !_isDisposed && requestVersion == _loadVersion;

  bool _isCurrentThumbnail(int requestVersion, int mediaId) =>
      !_isDisposed &&
      requestVersion == _thumbnailVersion &&
      state.selectedMedia?.mediaId == mediaId;

  bool _isCurrentSubtitle(int requestVersion) =>
      !_isDisposed && requestVersion == _subtitleVersion;

  void _disposeResources() {
    // 页面 dispose 会先显式 flush；这里不再重复：ref 生命周期回调中读 state 会
    // 触发 riverpod 3.x 的 `_debugCallbackStack` 断言。
    _isDisposed = true;
    _loadVersion += 1;
    _thumbnailVersion += 1;
    _subtitleVersion += 1;
    _stopProgressTimer();
    _activeThumbnailIndexNotifier.dispose();
  }
}
