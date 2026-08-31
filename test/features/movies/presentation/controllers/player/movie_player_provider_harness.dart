import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sakuramedia/features/media/data/media_storage_descriptor.dart';
import 'package:sakuramedia/features/movies/data/dto/detail/movie_detail_dto.dart';
import 'package:sakuramedia/features/movies/data/dto/thumbnails/movie_media_thumbnail_dto.dart';
import 'package:sakuramedia/features/movies/presentation/controllers/player/movie_player_subtitle_state.dart';
import 'package:sakuramedia/features/movies/presentation/providers/movie_player_provider.dart';
import 'package:sakuramedia/features/movies/presentation/providers/movie_player_scope.dart';
import 'package:sakuramedia/features/movies/presentation/providers/movie_player_state.dart';

/// 让原控制器回归逐项落到真实 Riverpod provider 上的测试适配器。
class MoviePlayerHarness {
  MoviePlayerHarness({
    required String movieNumber,
    required String baseUrl,
    required FetchMovieDetail fetchMovieDetail,
    required FetchMediaThumbnails fetchMediaThumbnails,
    FetchMovieSubtitles? fetchMovieSubtitles,
    required UpdateMediaProgress updateMediaProgress,
    FetchMediaLibraries? fetchMediaLibraries,
    int? initialMediaId,
    int? initialPositionSeconds,
    Duration progressReportInterval = const Duration(seconds: 5),
  }) : _scope = MoviePlayerScope(
         movieNumber: movieNumber,
         baseUrl: baseUrl,
         initialMediaId: initialMediaId,
         initialPositionSeconds: initialPositionSeconds,
         progressReportInterval: progressReportInterval,
       ) {
    _container = ProviderContainer(
      overrides: [
        moviePlayerDependenciesProvider.overrideWithValue(
          MoviePlayerDependencies(
            fetchMovieDetail: fetchMovieDetail,
            fetchMediaThumbnails: fetchMediaThumbnails,
            fetchMovieSubtitles: fetchMovieSubtitles,
            updateMediaProgress: updateMediaProgress,
            fetchMediaLibraries: fetchMediaLibraries,
          ),
        ),
      ],
    );
    _subscription = _container.listen(moviePlayerProvider(_scope), (_, __) {
      for (final listener in List<VoidCallback>.of(_listeners)) {
        listener();
      }
    }, fireImmediately: true);
    _notifier = _container.read(moviePlayerProvider(_scope).notifier);
  }

  final MoviePlayerScope _scope;
  late final ProviderContainer _container;
  late final ProviderSubscription<MoviePlayerState> _subscription;
  late final MoviePlayer _notifier;
  final List<VoidCallback> _listeners = <VoidCallback>[];

  MoviePlayerState get _state => _container.read(moviePlayerProvider(_scope));

  MovieDetailDto? get movie => _state.movie;
  MovieMediaItemDto? get selectedMedia => _state.selectedMedia;
  MediaStorageDescriptor get selectedMediaStorage =>
      _state.selectedMediaStorage;
  List<MovieMediaThumbnailDto> get thumbnails => _state.thumbnails;
  String? get thumbnailErrorMessage => _state.thumbnailErrorMessage;
  String? get subtitleErrorMessage => _state.subtitleErrorMessage;
  String get subtitleFetchStatus => _state.subtitleFetchStatus;
  bool get isThumbnailScrollLocked => _state.isThumbnailScrollLocked;
  int? get thumbnailColumns => _state.thumbnailColumns;
  bool get clipSelectionMode => _state.clipSelectionMode;
  int? get clipStartIndex => _state.clipStartIndex;
  int? get clipEndIndex => _state.clipEndIndex;
  MovieMediaThumbnailDto? get clipStartThumbnail => _state.clipStartThumbnail;
  MovieMediaThumbnailDto? get clipEndThumbnail => _state.clipEndThumbnail;
  bool get canCreateClip => _state.canCreateClip;
  int? get clipSelectionDurationSeconds => _state.clipSelectionDurationSeconds;
  int get currentPlaybackSeconds => _notifier.currentPlaybackSeconds;
  int? get activeThumbnailIndex => _notifier.activeThumbnailIndex;
  ValueListenable<int?> get activeThumbnailIndexListenable =>
      _notifier.activeThumbnailIndexListenable;
  List<MoviePlayerSubtitleOption> get subtitleOptions => _state.subtitleOptions;
  int? get selectedSubtitleId => _state.selectedSubtitleId;
  String? get resolvedPlayUrl => _state.resolvedPlayUrl(_scope.baseUrl);
  Duration? get initialPlaybackPosition => _state.startupPlaybackPosition;
  Duration? get resumePlaybackPosition => _state.resumePlaybackPosition;
  bool get isResumeDecisionPending => _state.isResumeDecisionPending;

  void addListener(VoidCallback listener) => _listeners.add(listener);

  Future<void> load() => _notifier.load();
  void applyAutoThumbnailColumns(int count) =>
      _notifier.applyAutoThumbnailColumns(count);
  void setThumbnailColumns(int count) => _notifier.setThumbnailColumns(count);
  void toggleThumbnailScrollLock() => _notifier.toggleThumbnailScrollLock();
  void toggleClipSelectionMode() => _notifier.toggleClipSelectionMode();
  void handleClipSelectionTap(int index) =>
      _notifier.handleClipSelectionTap(index);
  void clearClipSelection() => _notifier.clearClipSelection();
  void setSelectedSubtitleId(int? subtitleId) =>
      _notifier.setSelectedSubtitleId(subtitleId);
  void handleThumbnailTap(int index) => _notifier.handleThumbnailTap(index);
  void handlePlaybackPosition(Duration position) =>
      _notifier.handlePlaybackPosition(position);
  void handlePlaybackPlayingChanged(bool isPlaying) =>
      _notifier.handlePlaybackPlayingChanged(isPlaying);
  void resolveResumePrompt() => _notifier.resolveResumePrompt();
  Future<void> flushPlaybackProgress() => _notifier.flushPlaybackProgress();

  void dispose() {
    _subscription.close();
    _container.dispose();
  }
}
