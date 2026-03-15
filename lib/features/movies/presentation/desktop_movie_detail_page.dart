import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:sakuramedia/core/network/api_error_message.dart';
import 'package:sakuramedia/core/network/api_exception.dart';
import 'package:sakuramedia/features/movies/data/movies_api.dart';
import 'package:sakuramedia/features/movies/presentation/movie_detail_controller.dart';
import 'package:sakuramedia/features/movies/presentation/movie_detail_page_content.dart';
import 'package:sakuramedia/features/movies/presentation/movie_plot_image_actions.dart';
import 'package:sakuramedia/features/movies/presentation/paged_movie_summary_controller.dart';
import 'package:sakuramedia/features/playlists/presentation/movie_playlist_picker_dialog.dart';
import 'package:sakuramedia/features/subscriptions/presentation/subscription_feedback.dart';
import 'package:sakuramedia/routes/app_navigation.dart';
import 'package:sakuramedia/widgets/movie_detail/movie_detail_inspector_dialog.dart';
import 'package:sakuramedia/widgets/movie_detail/movie_plot_preview_overlay.dart';

class DesktopMovieDetailPage extends StatefulWidget {
  const DesktopMovieDetailPage({super.key, required this.movieNumber});

  final String movieNumber;

  @override
  State<DesktopMovieDetailPage> createState() => _DesktopMovieDetailPageState();
}

class _DesktopMovieDetailPageState extends State<DesktopMovieDetailPage> {
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
    return AnimatedBuilder(
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
          isSubscribed: isSubscribed,
          isSubscriptionUpdating: _isSubscriptionUpdating,
          selectedMediaId: selectedMedia?.mediaId,
          statItems: buildMovieDetailStatItems(context, movie),
          onSubscriptionTap:
              _isSubscriptionUpdating
                  ? null
                  : () => _toggleMovieSubscription(isSubscribed: isSubscribed),
          onPlayTap:
              selectedMedia != null && selectedMedia.hasPlayableUrl
                  ? () => context.push(
                    buildDesktopMoviePlayerRoutePath(
                      widget.movieNumber,
                      mediaId: selectedMedia.mediaId,
                    ),
                  )
                  : null,
          onPlaylistTap:
              () => showMoviePlaylistPickerDialog(
                context,
                movieNumber: widget.movieNumber,
                initialPlaylists: movie.playlists,
                presentation: MoviePlaylistPickerPresentation.dialog,
              ),
          onMediaSelect:
              (item) => setState(() {
                _selectedMediaId = item.mediaId;
              }),
          onActorTap:
              (actor) => context.goNamed(
                'desktop-actor-detail',
                pathParameters: <String, String>{
                  'actorId': actor.id.toString(),
                },
                extra: '/desktop/library/movies/${widget.movieNumber}',
              ),
          onRequestPlotImageMenu:
              (menuContext, index, globalPosition) =>
                  showMoviePlotImageActionMenu(
                    context: menuContext,
                    hostContext: context,
                    plotImages: movie.plotImages,
                    movieNumber: widget.movieNumber,
                    index: index,
                    globalPosition: globalPosition,
                  ),
          onOpenPlotPreview:
              (index) => showMoviePlotPreviewOverlay(
                context: context,
                plotImages: movie.plotImages,
                initialIndex: index,
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
                        ),
              ),
          onInspectorTap:
              () => showMovieDetailInspectorDialog(
                context: context,
                movieNumber: movie.movieNumber,
                selectedMedia: selectedMedia,
              ),
        );
      },
    );
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
