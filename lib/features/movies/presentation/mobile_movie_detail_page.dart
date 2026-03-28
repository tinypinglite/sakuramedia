import 'package:flutter/material.dart';
import 'package:oktoast/oktoast.dart';
import 'package:provider/provider.dart';
import 'package:sakuramedia/core/network/api_client.dart';
import 'package:sakuramedia/core/network/api_error_message.dart';
import 'package:sakuramedia/core/network/api_exception.dart';
import 'package:sakuramedia/features/image_search/presentation/image_search_draft_store.dart';
import 'package:sakuramedia/features/image_search/presentation/image_search_file_picker.dart';
import 'package:sakuramedia/features/movies/data/movies_api.dart';
import 'package:sakuramedia/features/movies/presentation/movie_detail_controller.dart';
import 'package:sakuramedia/features/movies/presentation/movie_detail_page_content.dart';
import 'package:sakuramedia/features/movies/presentation/movie_plot_image_actions.dart';
import 'package:sakuramedia/features/movies/presentation/paged_movie_summary_controller.dart';
import 'package:sakuramedia/features/playlists/presentation/movie_playlist_picker_dialog.dart';
import 'package:sakuramedia/features/subscriptions/presentation/subscription_feedback.dart';
import 'package:sakuramedia/routes/mobile_routes.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/movie_detail/movie_detail_inspector_dialog.dart';
import 'package:sakuramedia/widgets/movie_detail/movie_detail_bottom_info_bar.dart';
import 'package:sakuramedia/widgets/movie_detail/movie_plot_preview_overlay.dart';

class MobileMovieDetailPage extends StatefulWidget {
  const MobileMovieDetailPage({super.key, required this.movieNumber});

  final String movieNumber;

  @override
  State<MobileMovieDetailPage> createState() => _MobileMovieDetailPageState();
}

class _MobileMovieDetailPageState extends State<MobileMovieDetailPage> {
  late final MovieDetailController _controller;
  int? _selectedMediaId;
  bool? _isSubscribedOverride;
  bool _isSubscriptionUpdating = false;

  @override
  void initState() {
    super.initState();
    _controller = MovieDetailController(
      movieNumber: widget.movieNumber,
      fetchMovieDetail: context.read<MoviesApi>().getMovieDetail,
    )..load();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      key: const Key('mobile-movie-detail-page-surface'),
      color: context.appColors.surfaceCard,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          if (_controller.isLoading) {
            return MovieDetailLoadingSkeleton(controller: _controller);
          }

          if (_controller.errorMessage != null || _controller.movie == null) {
            return MovieDetailErrorState(
              message: _controller.errorMessage ?? '影片详情暂时无法加载，请稍后重试',
              onRetry: _controller.load,
            );
          }

          final movie = _controller.movie!;
          final isSubscribed = _isSubscribedOverride ?? movie.isSubscribed;
          final selectedMedia =
              movie.mediaItems
                  .where((item) => item.mediaId == _selectedMediaId)
                  .firstOrNull ??
              (movie.mediaItems.isNotEmpty ? movie.mediaItems.first : null);

          return MovieDetailPageContent(
            movie: movie,
            selectedPreviewKey: _controller.selectedPreviewKey,
            selectedPreviewUrl: _controller.selectedPreviewUrl,
            contentPadding: EdgeInsets.symmetric(
              horizontal: context.appSpacing.sm,
            ),
            bottomInfoBarVariant:
                MovieDetailBottomInfoBarVariant.mobileFullWidth,
            isSubscribed: isSubscribed,
            isSubscriptionUpdating: _isSubscriptionUpdating,
            selectedMediaId: selectedMedia?.mediaId,
            statItems: buildMovieDetailStatItems(context, movie),
            onSubscriptionTap:
                _isSubscriptionUpdating
                    ? null
                    : () =>
                        _toggleMovieSubscription(isSubscribed: isSubscribed),
            onPlayTap:
                selectedMedia != null && selectedMedia.hasPlayableUrl
                    ? () => _openMoviePlayer(mediaId: selectedMedia.mediaId)
                    : null,
            onPlaylistTap:
                () => showMoviePlaylistPickerDialog(
                  context,
                  movieNumber: widget.movieNumber,
                  initialPlaylists: movie.playlists,
                  presentation: MoviePlaylistPickerPresentation.bottomDrawer,
                ),
            onMediaSelect:
                (item) => setState(() {
                  _selectedMediaId = item.mediaId;
                }),
            onActorTap:
                (actor) =>
                    MobileActorDetailRouteData(actorId: actor.id).push(context),
            onRequestPlotImageMenu:
                (menuContext, index, globalPosition) =>
                    showMoviePlotImageActionMenu(
                      context: menuContext,
                      hostContext: context,
                      plotImages: movie.plotImages,
                      movieNumber: widget.movieNumber,
                      index: index,
                      globalPosition: globalPosition,
                      onSearchSimilar:
                          (hostContext, imageUrl, fileName) =>
                              _openImageSearchFromUrl(
                                imageUrl: imageUrl,
                                fileName: fileName,
                              ),
                    ),
            onOpenPlotPreview:
                (index) => showMoviePlotPreviewOverlay(
                  context: context,
                  plotImages: movie.plotImages,
                  initialIndex: index,
                  presentation: MoviePlotPreviewPresentation.bottomDrawer,
                  onRequestImageMenu:
                      (menuContext, previewIndex, globalPosition) =>
                          showMoviePlotImageActionMenu(
                            context: menuContext,
                            hostContext: context,
                            plotImages: movie.plotImages,
                            movieNumber: widget.movieNumber,
                            index: previewIndex,
                            globalPosition: globalPosition,
                            closeCurrentRouteOnSearch: true,
                            onSearchSimilar:
                                (hostContext, imageUrl, fileName) =>
                                    _openImageSearchFromUrl(
                                      imageUrl: imageUrl,
                                      fileName: fileName,
                                    ),
                          ),
                ),
            onInspectorTap:
                () => showMobileMovieDetailInspectorBottomSheet(
                  context: context,
                  movieNumber: movie.movieNumber,
                  selectedMedia: selectedMedia,
                  onSearchSimilar: (thumbnail, imageUrl, fileName) {
                    return _openImageSearchFromUrl(
                      imageUrl: imageUrl,
                      fileName: fileName,
                    );
                  },
                  onPlay:
                      (thumbnail) => _openMoviePlayer(
                        mediaId:
                            thumbnail.mediaId > 0
                                ? thumbnail.mediaId
                                : selectedMedia?.mediaId,
                        positionSeconds: thumbnail.offsetSeconds,
                      ),
                ),
          );
        },
      ),
    );
  }

  void _openMoviePlayer({int? mediaId, int? positionSeconds}) {
    MobileMoviePlayerRouteData(
      movieNumber: widget.movieNumber,
      mediaId: mediaId,
      positionSeconds: positionSeconds,
    ).push(context);
  }

  Future<void> _openImageSearchFromUrl({
    required String imageUrl,
    required String fileName,
  }) async {
    try {
      final imageBytes = await context.read<ApiClient>().getBytes(imageUrl);
      if (!mounted) {
        return;
      }
      final draftId = context.read<ImageSearchDraftStore>().save(
        fileName: fileName,
        bytes: imageBytes,
        mimeType: guessImageMimeType(fileName),
      );
      MobileImageSearchRouteData(
        draftId: draftId,
        currentMovieNumber: widget.movieNumber,
      ).push(context);
    } catch (error) {
      if (!mounted) {
        return;
      }
      showToast(apiErrorMessage(error, fallback: '读取图片失败，请稍后重试'));
    }
  }

  Future<void> _toggleMovieSubscription({required bool isSubscribed}) async {
    if (_isSubscriptionUpdating) {
      return;
    }

    setState(() {
      _isSubscriptionUpdating = true;
    });

    MovieSubscriptionToggleResult result;

    try {
      if (isSubscribed) {
        await context.read<MoviesApi>().unsubscribeMovie(
          movieNumber: widget.movieNumber,
          deleteMedia: false,
        );
        result = const MovieSubscriptionToggleResult.unsubscribed();
        _isSubscribedOverride = false;
      } else {
        await context.read<MoviesApi>().subscribeMovie(
          movieNumber: widget.movieNumber,
        );
        result = const MovieSubscriptionToggleResult.subscribed();
        _isSubscribedOverride = true;
      }
    } catch (error) {
      if (_isBlockedByMedia(error)) {
        result = const MovieSubscriptionToggleResult.blockedByMedia();
      } else {
        result = MovieSubscriptionToggleResult.failed(
          message: apiErrorMessage(
            error,
            fallback: isSubscribed ? '取消订阅影片失败' : '订阅影片失败',
          ),
        );
      }
    }

    if (!mounted) {
      return;
    }

    setState(() {
      _isSubscriptionUpdating = false;
    });
    showMovieSubscriptionFeedback(result);
  }

  bool _isBlockedByMedia(Object error) {
    return error is ApiException &&
        error.error?.code == 'movie_subscription_has_media';
  }
}
