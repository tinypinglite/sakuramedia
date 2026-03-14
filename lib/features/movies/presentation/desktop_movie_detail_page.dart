import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:sakuramedia/core/network/api_error_message.dart';
import 'package:sakuramedia/core/network/api_exception.dart';
import 'package:sakuramedia/features/movies/data/movie_detail_dto.dart';
import 'package:sakuramedia/features/movies/data/movies_api.dart';
import 'package:sakuramedia/features/movies/presentation/movie_detail_controller.dart';
import 'package:sakuramedia/features/movies/presentation/paged_movie_summary_controller.dart';
import 'package:sakuramedia/features/movies/presentation/movie_plot_image_actions.dart';
import 'package:sakuramedia/features/playlists/presentation/movie_playlist_picker_dialog.dart';
import 'package:sakuramedia/features/subscriptions/presentation/subscription_feedback.dart';
import 'package:sakuramedia/routes/app_navigation.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/actions/app_icon_button.dart';
import 'package:sakuramedia/widgets/app_shell/app_empty_state.dart';
import 'package:sakuramedia/widgets/movie_detail/movie_actor_wrap.dart';
import 'package:sakuramedia/widgets/movie_detail/movie_detail_bottom_info_bar.dart';
import 'package:sakuramedia/widgets/movie_detail/movie_detail_hero_card.dart';
import 'package:sakuramedia/widgets/movie_detail/movie_detail_inspector_dialog.dart';
import 'package:sakuramedia/widgets/movie_detail/movie_detail_section.dart';
import 'package:sakuramedia/widgets/movie_detail/movie_detail_stat_row.dart';
import 'package:sakuramedia/widgets/movie_detail/movie_media_item_list.dart';
import 'package:sakuramedia/widgets/movie_detail/movie_plot_gallery.dart';
import 'package:sakuramedia/widgets/movie_detail/movie_plot_preview_overlay.dart';
import 'package:sakuramedia/widgets/movie_detail/movie_tag_wrap.dart';

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
          return _MovieDetailLoadingSkeleton(controller: _controller);
        }

        if (_controller.errorMessage != null || _controller.movie == null) {
          return _MovieDetailErrorState(
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
        final selectedMediaId = selectedMedia?.mediaId;
        final statItems = _buildStatItems(movie);

        return Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                child: Padding(
                  padding: EdgeInsets.only(
                    bottom:
                        context
                            .appComponentTokens
                            .movieDetailBottomBarMinHeight +
                        context.appSpacing.sm,
                  ),
                  child: Column(
                    key: const Key('movie-detail-page'),
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      MovieDetailHeroCard(
                        mainImageKey: _controller.selectedPreviewKey,
                        mainImageUrl: _controller.selectedPreviewUrl,
                        thinCoverUrl: movie.thinCoverImage?.bestAvailableUrl,
                        canPlay: movie.canPlay,
                        isSubscribed: isSubscribed,
                        isCollection: movie.isCollection,
                        onSubscriptionTap:
                            _isSubscriptionUpdating
                                ? null
                                : () => _toggleMovieSubscription(
                                  isSubscribed: isSubscribed,
                                ),
                        isSubscriptionUpdating: _isSubscriptionUpdating,
                        onPlayTap:
                            selectedMedia != null &&
                                    selectedMedia.hasPlayableUrl
                                ? () => context.push(
                                  buildDesktopMoviePlayerRoutePath(
                                    widget.movieNumber,
                                    mediaId: selectedMedia.mediaId,
                                  ),
                                )
                                : null,
                      ),
                      SizedBox(height: context.appSpacing.lg),
                      MoviePlotGallery(
                        plotImages: movie.plotImages,
                        onRequestImageMenu:
                            (menuContext, index, globalPosition) =>
                                showMoviePlotImageActionMenu(
                                  context: menuContext,
                                  hostContext: context,
                                  plotImages: movie.plotImages,
                                  movieNumber: widget.movieNumber,
                                  index: index,
                                  globalPosition: globalPosition,
                                ),
                        onOpenPreview:
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
                      ),
                      SizedBox(
                        height:
                            context.appComponentTokens.movieDetailSectionGap,
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.start,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Text(
                            movie.movieNumber,
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                          SizedBox(width: context.appSpacing.xs),
                          AppIconButton(
                            key: const Key('movie-detail-playlist-trigger'),
                            onPressed:
                                () => showMoviePlaylistPickerDialog(
                                  context,
                                  movieNumber: widget.movieNumber,
                                  initialPlaylists: movie.playlists,
                                ),
                            icon: Icon(
                              Icons.playlist_add_rounded,
                              size: context.appComponentTokens.iconSizeLg,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                            tooltip: '加入播放列表',
                          ),
                        ],
                      ),

                      MovieDetailSection(
                        title: '标签',
                        child: MovieTagWrap(tags: movie.tags),
                      ),
                      movie.seriesName.trim().isNotEmpty
                          ? MovieDetailSection(
                            title: '系列',
                            child: Text(
                              movie.seriesName.trim(),
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          )
                          : SizedBox(),
                      MovieDetailSection(
                        title: '演员',
                        titleBottomSpacing: context.appSpacing.xs,
                        child: MovieActorWrap(
                          actors: movie.actors,
                          onActorTap:
                              (actor) => context.goNamed(
                                'desktop-actor-detail',
                                pathParameters: <String, String>{
                                  'actorId': actor.id.toString(),
                                },
                                extra:
                                    '/desktop/library/movies/${widget.movieNumber}',
                              ),
                        ),
                      ),
                      if (movie.mediaItems.isNotEmpty)
                        MovieDetailSection(
                          title: '媒体源',
                          child: MovieMediaItemList(
                            mediaItems: movie.mediaItems,
                            selectedMediaId: selectedMediaId,
                            onSelect:
                                (item) => setState(() {
                                  _selectedMediaId = item.mediaId;
                                }),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
            SizedBox(height: context.appSpacing.xs),
            MovieDetailBottomInfoBar(
              items: statItems,
              onTap:
                  () => showMovieDetailInspectorDialog(
                    context: context,
                    movieNumber: movie.movieNumber,
                    selectedMedia: selectedMedia,
                  ),
            ),
          ],
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

  List<MovieDetailStatItem> _buildStatItems(MovieDetailDto movie) {
    final releaseLabel =
        movie.releaseDate == null
            ? '--'
            : DateFormat('yy/MM/dd').format(movie.releaseDate!);
    final durationLabel =
        movie.durationMinutes > 0 ? '${movie.durationMinutes} 分钟' : '--';
    final scoreLabel = movie.score > 0 ? movie.score.toStringAsFixed(1) : '--';
    final scoreNumberLabel =
        movie.scoreNumber > 0 ? '${movie.scoreNumber}' : '--';
    final commentCountLabel =
        movie.commentCount > 0 ? '${movie.commentCount}' : '--';
    final wantWatchCountLabel =
        movie.wantWatchCount > 0 ? '${movie.wantWatchCount}' : '--';

    return [
      MovieDetailStatItem(
        icon: Icons.calendar_today_outlined,
        label: releaseLabel,
        tooltip: '发行日期',
        iconColor: context.appColors.movieDetailReleaseDateIcon,
      ),
      MovieDetailStatItem(
        icon: Icons.schedule_outlined,
        label: durationLabel,
        tooltip: '影片时长',
        iconColor: context.appColors.movieDetailDurationIcon,
      ),
      MovieDetailStatItem(
        icon: Icons.star_outline_rounded,
        label: scoreLabel,
        tooltip: '评分',
        iconColor: context.appColors.movieDetailScoreIcon,
      ),
      MovieDetailStatItem(
        icon: Icons.how_to_vote_outlined,
        label: scoreNumberLabel,
        tooltip: '评分人数',
        iconColor: context.appColors.movieDetailScoreCountIcon,
      ),
      MovieDetailStatItem(
        icon: Icons.chat_bubble_outline_rounded,
        label: commentCountLabel,
        tooltip: '评论数',
        iconColor: context.appColors.movieDetailCommentCountIcon,
      ),
      MovieDetailStatItem(
        icon: Icons.favorite_border_rounded,
        label: wantWatchCountLabel,
        tooltip: '想看人数',
        iconColor: context.appColors.movieDetailWantWatchCountIcon,
      ),
    ];
  }
}

extension on Iterable<MovieMediaItemDto> {
  MovieMediaItemDto? get firstOrNull {
    for (final item in this) {
      return item;
    }
    return null;
  }
}

class _MovieDetailLoadingSkeleton extends StatelessWidget {
  const _MovieDetailLoadingSkeleton({required this.controller});

  final MovieDetailController controller;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            key: const Key('movie-detail-loading-skeleton'),
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _SkeletonBlock(
                height: context.appComponentTokens.movieDetailHeroHeight,
              ),
              SizedBox(height: context.appSpacing.lg),
              _SkeletonBlock(
                height:
                    context.appComponentTokens.movieDetailPlotThumbnailHeight,
              ),
              SizedBox(height: context.appSpacing.xl),
              _SkeletonBlock(height: 28, width: 240),
              SizedBox(height: context.appSpacing.md),
              _SkeletonBlock(height: 18, width: 520),
              SizedBox(height: context.appSpacing.xxl),
              _SkeletonBlock(height: 18, width: 120),
              SizedBox(height: context.appSpacing.md),
              _SkeletonBlock(height: 64),
              SizedBox(height: context.appSpacing.lg),
              _SkeletonBlock(height: 18, width: 120),
              SizedBox(height: context.appSpacing.md),
              _SkeletonBlock(height: 96),
            ],
          ),
        ],
      ),
    );
  }
}

class _MovieDetailErrorState extends StatelessWidget {
  const _MovieDetailErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        AppEmptyState(message: message),
        SizedBox(height: context.appSpacing.lg),
        TextButton(onPressed: onRetry, child: const Text('重试')),
      ],
    );
  }
}

class _SkeletonBlock extends StatelessWidget {
  const _SkeletonBlock({required this.height, this.width});

  final double height;
  final double? width;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width ?? double.infinity,
      height: height,
      decoration: BoxDecoration(
        color: context.appColors.surfaceMuted,
        borderRadius: context.appRadius.mdBorder,
      ),
    );
  }
}
