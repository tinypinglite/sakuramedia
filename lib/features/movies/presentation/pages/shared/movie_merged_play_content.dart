import 'package:sakuramedia/features/status/presentation/providers/server_capabilities_provider.dart';
import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:sakuramedia/core/media/media_url_resolver.dart';
import 'package:sakuramedia/core/network/api_error_message.dart';
import 'package:sakuramedia/core/session/providers/session_store_provider.dart';
import 'package:sakuramedia/features/media/presentation/providers/media_api_provider.dart';
import 'package:sakuramedia/features/movies/data/dto/detail/movie_detail_dto.dart';
import 'package:sakuramedia/features/movies/presentation/actions/movie_merge_playback_candidates.dart';
import 'package:sakuramedia/features/movies/presentation/pages/shared/movie_player_layout.dart';
import 'package:sakuramedia/features/movies/presentation/providers/movie_merged_playback_factory_provider.dart';
import 'package:sakuramedia/features/movies/presentation/providers/movies_api_provider.dart';
import 'package:sakuramedia/l10n/app_localizations.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/features/image_search/presentation/actions/image_search_launcher.dart';
import 'package:sakuramedia/routes/app_navigation.dart';
import 'package:sakuramedia/widgets/base/media/images/app_image_action_menu.dart';
import 'package:sakuramedia/widgets/base/overlays/app_action_menu.dart';
import 'package:sakuramedia/widgets/domain/media/media_thumbnail_action_support.dart';
import 'package:sakuramedia/widgets/base/media/video/themed_video_player.dart';
import 'package:sakuramedia/l10n/app_localizations.dart';
import 'package:sakuramedia/widgets/base/media/video/player_app_fullscreen.dart';
import 'package:sakuramedia/widgets/domain/collections/playback/collection_filmstrip_controller.dart';
import 'package:sakuramedia/widgets/domain/collections/playback/collection_play_split_layout.dart';
import 'package:sakuramedia/widgets/domain/collections/playback/collection_playback_page_mixin.dart';
import 'package:sakuramedia/widgets/domain/collections/playback/episode_selector_overlay.dart';
import 'package:sakuramedia/widgets/domain/movies/player/merged_position_indicator.dart';
import 'package:sakuramedia/widgets/domain/movies/player/movie_player_back_overlay.dart';
import 'package:sakuramedia/widgets/domain/movies/player/movie_player_controls.dart';

class MovieMergedPlayContent extends ConsumerStatefulWidget {
  const MovieMergedPlayContent({
    super.key,
    required this.movieNumber,
    required this.libraryId,
    required this.fallbackPath,
    this.useTouchOptimizedControls = false,
    this.imageSearchRoutePath = desktopImageSearchPath,
  });

  final String movieNumber;
  final int libraryId;
  final String fallbackPath;
  final bool useTouchOptimizedControls;
  final String imageSearchRoutePath;

  @override
  ConsumerState<MovieMergedPlayContent> createState() =>
      _MovieMergedPlayContentState();
}

class _MovieMergedPlayContentState extends ConsumerState<MovieMergedPlayContent>
    with
        CollectionPlaybackPageMixin<MovieMergedPlayContent>,
        PlayerAppFullscreenStateMixin<MovieMergedPlayContent> {
  final _videoKey = GlobalKey<VideoState>();
  List<MovieMediaItemDto> _medias = const [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  bool get applySystemFullscreenForAppFullscreen =>
      !widget.useTouchOptimizedControls;

  @override
  void dispose() {
    disposePlayerAppFullscreen();
    disposePlayback();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final mediaApi = ref.read(mediaApiProvider);
      final baseUrl = ref.read(sessionStoreProvider).baseUrl;
      final movie = await ref
          .read(moviesApiProvider)
          .getMovieDetail(movieNumber: widget.movieNumber);
      if (!mounted) return;
      final medias = movieMergedPlaybackMedia(movie, widget.libraryId);
      if (medias.length < 2) {
        setState(() {
          _isLoading = false;
          _errorMessage = AppLocalizations.of(
            context,
          ).moviePageMergedNotEnoughSegments;
        });
        return;
      }
      final playlist = Playlist([
        for (final media in medias)
          Media(resolveMediaUrl(rawUrl: media.playUrl, baseUrl: baseUrl)!),
      ]);
      final playback = ref.read(movieMergedPlaybackFactoryProvider)();
      final frames = CollectionFilmstripController(
        episodeCount: medias.length,
        frameLoader: (index) async {
          final thumbnails = await mediaApi.getMediaThumbnails(
            mediaId: medias[index].mediaId,
          );
          return [
            for (final frame in thumbnails)
              (
                offsetSeconds: frame.offsetSeconds,
                image: frame.image,
                mediaId: frame.mediaId,
                thumbnailId: frame.thumbnailId,
                width: frame.width,
                height: frame.height,
              ),
          ];
        },
      );
      setState(() {
        _medias = medias;
        attachPlayback(
          player: playback.player,
          videoController: playback.videoController,
          filmstrip: frames,
          startIndex: 0,
          episodeDurationsSeconds: medias
              .map((media) => media.durationSeconds)
              .toList(),
        );
        _isLoading = false;
      });
      unawaited(frames.start(priorityEpisode: 0));
      await playback.player.open(playlist);
    } catch (error) {
      if (!mounted) return;
      disposePlayback();
      player = null;
      videoController = null;
      filmstrip = null;
      setState(() {
        _isLoading = false;
        final l10n = AppLocalizations.of(context);
        _errorMessage = apiErrorMessage(
          error,
          fallback: l10n.moviePageMergedLoadFailed,
          l10n: l10n,
        );
      });
    }
  }

  Future<void> _showThumbnailActions(int index, Offset globalPosition) async {
    final thumbnails = filmstrip!.thumbnails;
    if (index < 0 || index >= thumbnails.length) return;
    final thumbnail = thumbnails[index];
    final point = await tryFindMediaPointForThumbnail(
      ref: ref,
      thumbnail: thumbnail,
    );
    if (!mounted) return;
    final action = await showAppActionMenu<AppImageActionType>(
      context: context,
      globalPosition: globalPosition,
      items: buildImageActionMenuItems(
        buildMediaThumbnailActionDescriptors(
          l10n: AppLocalizations.of(context),
          showSearchSimilar: ref.read(imageSearchEnabledProvider),
          thumbnail: thumbnail,
          point: point,
        ),
      ),
    );
    if (!mounted || action == null) return;
    final fileName =
        'movie_player_${widget.movieNumber}_${thumbnail.thumbnailId}.webp';
    await handleMediaThumbnailAction(
      context: context,
      ref: ref,
      thumbnail: thumbnail,
      action: action,
      point: point,
      fileName: fileName,
      onSearchSimilar: () => launchImageSearchFromUrl(
        context,
        imageUrl: thumbnail.image.origin,
        routePath: widget.imageSearchRoutePath,
        fallbackPath: GoRouterState.of(context).uri.toString(),
        fileName: fileName,
        replaceRouteStack: true,
      ),
      onPlay: () async {
        final targetIndex = filmstrip!.thumbnails.indexWhere(
          (frame) =>
              frame.mediaId == thumbnail.mediaId &&
              frame.thumbnailId == thumbnail.thumbnailId,
        );
        if (targetIndex < 0) return;
        seekToFrame(targetIndex);
        await player?.play();
      },
    );
  }

  void _handleBack() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(widget.fallbackPath);
    }
  }

  Future<void> _showEpisodes() async {
    if (isEpisodePanelOpen) return;
    final fullscreen = _videoKey.currentState!.isFullscreen();
    final overlayBox =
        Navigator.of(
              context,
              rootNavigator: true,
            ).overlay!.context.findRenderObject()!
            as RenderBox;
    isEpisodePanelOpen = true;
    try {
      await showGeneralDialog<void>(
        context: context,
        barrierColor: Colors.transparent,
        pageBuilder: (panelContext, _, _) => StreamBuilder<Playlist>(
          stream: player!.stream.playlist,
          builder: (_, snapshot) => LayoutBuilder(
            builder: (_, constraints) {
              final box =
                  _videoKey.currentContext!.findRenderObject()! as RenderBox;
              final bounds = fullscreen
                  ? Offset.zero & constraints.biggest
                  : box.localToGlobal(Offset.zero, ancestor: overlayBox) &
                        box.size;
              return Stack(
                children: [
                  Positioned.fromRect(
                    rect: bounds,
                    child: Stack(
                      children: [
                        EpisodeSelectorOverlay(
                          isOpen: true,
                          itemCount: _medias.length,
                          currentIndex: player!.state.playlist.index,
                          title: AppLocalizations.of(
                            context,
                          ).moviePageEpisodePickerTitle(_medias.length),
                          onClose: () => Navigator.of(panelContext).pop(),
                          itemBuilder: (_, index) => ListTile(
                            key: Key('movie-merged-episode-$index'),
                            selected: index == player!.state.playlist.index,
                            leading: Text('${index + 1}'),
                            title: Text(
                              _medias[index].fileName,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            onTap: () {
                              Navigator.of(panelContext).pop();
                              unawaited(jumpTo(index));
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      );
    } finally {
      isEpisodePanelOpen = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final Widget body;
    if (_isLoading || _errorMessage != null) {
      body = wrapWithMoviePlayerBackButton(
        onBackPressed: _handleBack,
        child: _isLoading
            ? const MoviePlayerLoadingState()
            : MoviePlayerErrorState(message: _errorMessage!, onRetry: _load),
      );
    } else {
      body = CollectionPlaySplitLayout(
        keyPrefix: 'movie-merged',
        collapsible: true,
        panelAvailable: filmstrip != null,
        left: PlayerAppFullscreenDoubleTap(
          enabled: !widget.useTouchOptimizedControls,
          child: ThemedVideoPlayer(
            videoKey: _videoKey,
            videoController: videoController!,
            useTouchOptimizedControls: widget.useTouchOptimizedControls,
            guardInitialSeek: true,
            disableNativeFullscreen: true,
          playbackSessionKey: _medias[currentIndex].mediaId,
          displaySeekBar: false,
          topControls: [
            ...buildMoviePlayerTopControls(
              movieNumber: '',
              onBackPressed: _handleBack,
            ),
            Expanded(
              child: StreamBuilder<Playlist>(
                stream: player!.stream.playlist,
                builder: (context, snapshot) => Text(
                  '${widget.movieNumber} · ${_medias[player!.state.playlist.index].fileName}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: resolveAppTextStyle(
                    context,
                    size: AppTextSize.s14,
                    tone: AppTextTone.onMedia,
                  ),
                ),
              ),
            ),
          ],
          bottomControls: buildCollectionPlayBottomControls(
            useTouchOptimizedControls: widget.useTouchOptimizedControls,
            onOpenEpisodes: _showEpisodes,
            progressIndicator: MergedPositionIndicator(
              player: player!,
              episodeDurationsSeconds: episodeDurationsSeconds,
              onSeekGlobalSeconds: seekToGlobalSeconds,
            ),
          ),
          ),
        ),
        right: buildFilmstripPanel(
          onThumbnailMenuRequested: _showThumbnailActions,
        ),
      );
    }
    return PlayerSwipeBackGuard(
      enabled: widget.useTouchOptimizedControls,
      onBack: _handleBack,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: PlayerAppFullscreenScope(
          isFullscreen: isAppFullscreen,
          onToggle: toggleAppFullscreen,
          child: body,
        ),
      ),
    );
  }
}
