import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:sakuramedia/features/movies/data/movie_detail_dto.dart';
import 'package:sakuramedia/features/movies/presentation/movie_detail_controller.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/actions/app_icon_button.dart';
import 'package:sakuramedia/widgets/app_shell/app_empty_state.dart';
import 'package:sakuramedia/widgets/movie_detail/movie_actor_wrap.dart';
import 'package:sakuramedia/widgets/movie_detail/movie_detail_bottom_info_bar.dart';
import 'package:sakuramedia/widgets/movie_detail/movie_detail_number_bar.dart';
import 'package:sakuramedia/widgets/movie_detail/movie_detail_title.dart';
import 'package:sakuramedia/widgets/movie_detail/movie_detail_hero_card.dart';
import 'package:sakuramedia/widgets/movie_detail/movie_detail_section.dart';
import 'package:sakuramedia/widgets/movie_detail/movie_detail_stat_row.dart';
import 'package:sakuramedia/widgets/movie_detail/movie_media_item_list.dart';
import 'package:sakuramedia/widgets/movie_detail/movie_plot_gallery.dart';
import 'package:sakuramedia/widgets/movie_detail/movie_tag_wrap.dart';

class MovieDetailPageContent extends StatelessWidget {
  const MovieDetailPageContent({
    super.key,
    required this.movie,
    required this.selectedPreviewKey,
    required this.selectedPreviewUrl,
    required this.isSubscribed,
    required this.isSubscriptionUpdating,
    required this.selectedMediaId,
    required this.statItems,
    required this.onInspectorTap,
    required this.onPlaylistTap,
    required this.onMediaSelect,
    this.mediaItemsOverride,
    this.onOpenMediaPointPreview,
    this.onRequestMediaPointMenu,
    this.onPlayTap,
    this.onSubscriptionTap,
    this.onActorTap,
    this.onRequestPlotImageMenu,
    this.onOpenPlotPreview,
    this.contentPadding = EdgeInsets.zero,
    this.bottomInfoBarVariant = MovieDetailBottomInfoBarVariant.desktopCard,
  });

  final MovieDetailDto movie;
  final List<MovieMediaItemDto>? mediaItemsOverride;
  final String selectedPreviewKey;
  final String? selectedPreviewUrl;
  final bool isSubscribed;
  final bool isSubscriptionUpdating;
  final int? selectedMediaId;
  final List<MovieDetailStatItem> statItems;
  final VoidCallback onInspectorTap;
  final VoidCallback onPlaylistTap;
  final ValueChanged<MovieMediaItemDto> onMediaSelect;
  final void Function(MovieMediaItemDto mediaItem, MovieMediaPointDto point)?
  onOpenMediaPointPreview;
  final Future<void> Function(
    BuildContext context,
    MovieMediaItemDto mediaItem,
    MovieMediaPointDto point,
    Offset globalPosition,
  )?
  onRequestMediaPointMenu;
  final VoidCallback? onPlayTap;
  final VoidCallback? onSubscriptionTap;
  final ValueChanged<MovieActorDto>? onActorTap;
  final Future<void> Function(
    BuildContext context,
    int index,
    Offset globalPosition,
  )?
  onRequestPlotImageMenu;
  final ValueChanged<int>? onOpenPlotPreview;
  final EdgeInsetsGeometry contentPadding;
  final MovieDetailBottomInfoBarVariant bottomInfoBarVariant;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: context.appColors.surfaceCard,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final viewportHeight = _resolveViewportHeight(context, constraints);
          final heroHeight = viewportHeight * 0.3;
          final scrollBottomPadding =
              bottomInfoBarVariant ==
                      MovieDetailBottomInfoBarVariant.mobileFullWidth
                  ? context.appComponentTokens.movieDetailBottomBarMinHeight
                  : context.appComponentTokens.movieDetailBottomBarMinHeight +
                      context.appSpacing.sm;

          final scrollableContent = SingleChildScrollView(
            child: Padding(
              padding: EdgeInsets.only(bottom: scrollBottomPadding),
              child: Padding(
                padding: contentPadding,
                child: _buildDetailBody(
                  context: context,
                  heroHeight: heroHeight,
                ),
              ),
            ),
          );

          if (bottomInfoBarVariant ==
              MovieDetailBottomInfoBarVariant.desktopCard) {
            return Column(
              children: [
                Expanded(child: scrollableContent),
                SizedBox(height: context.appSpacing.xs),
                MovieDetailBottomInfoBar(
                  items: statItems,
                  onTap: onInspectorTap,
                ),
              ],
            );
          }

          return Stack(
            children: [
              Positioned.fill(child: scrollableContent),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: MovieDetailBottomInfoBar(
                  items: statItems,
                  onTap: onInspectorTap,
                  variant: MovieDetailBottomInfoBarVariant.mobileFullWidth,
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildDetailBody({
    required BuildContext context,
    required double heroHeight,
  }) {
    final mediaItems = mediaItemsOverride ?? movie.mediaItems;
    final orderedActors = <MovieActorDto>[
      ...movie.actors.where((actor) => actor.isFemale),
      ...movie.actors.where((actor) => !actor.isFemale),
    ];
    final playlistTrigger = AppIconButton(
      key: const Key('movie-detail-playlist-trigger'),
      onPressed: onPlaylistTap,
      icon: Icon(
        Icons.playlist_add_rounded,
        size: context.appComponentTokens.iconSizeLg,
        color: Theme.of(context).colorScheme.primary,
      ),
      tooltip: '加入播放列表',
    );

    return Column(
      key: const Key('movie-detail-page'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        MovieDetailTitle(title: movie.title, movieNumber: movie.movieNumber),
        MovieDetailHeroCard(
          height: heroHeight,
          mainImageKey: selectedPreviewKey,
          mainImageUrl: selectedPreviewUrl,
          thinCoverUrl: movie.thinCoverImage?.bestAvailableUrl,
          canPlay: movie.canPlay,
          isSubscribed: isSubscribed,
          isCollection: movie.isCollection,
          onSubscriptionTap: onSubscriptionTap,
          isSubscriptionUpdating: isSubscriptionUpdating,
          onPlayTap: onPlayTap,
        ),
        SizedBox(height: context.appSpacing.lg),
        MoviePlotGallery(
          plotImages: movie.plotImages,
          onRequestImageMenu: onRequestPlotImageMenu,
          onOpenPreview: onOpenPlotPreview,
        ),
        SizedBox(height: context.appComponentTokens.movieDetailSectionGap),
        MovieDetailNumberBar(
          movieNumber: movie.movieNumber,
          summary: movie.summary,
          wantWatchCount: movie.wantWatchCount,
          watchedCount: movie.watchedCount,
          score: movie.score,
          commentCount: movie.commentCount,
          scoreNumber: movie.scoreNumber,
          trailing: playlistTrigger,
        ),
        ..._buildInlineMetaItems(context, movie),
        MovieDetailSection(title: '标签', child: MovieTagWrap(tags: movie.tags)),
        MovieDetailSection(
          title: '演员',
          titleBottomSpacing: context.appSpacing.xs,
          child: MovieActorWrap(actors: orderedActors, onActorTap: onActorTap),
        ),
        if (mediaItems.isNotEmpty)
          MovieDetailSection(
            title: '媒体源',
            child: MovieMediaItemList(
              mediaItems: mediaItems,
              selectedMediaId: selectedMediaId,
              onSelect: onMediaSelect,
              onOpenPointPreview: onOpenMediaPointPreview,
              onRequestPointMenu: onRequestMediaPointMenu,
            ),
          ),
      ],
    );
  }
}

List<Widget> _buildInlineMetaItems(BuildContext context, MovieDetailDto movie) {
  final items = <MapEntry<String, String>>[
    MapEntry('系列', movie.seriesName.trim()),
    MapEntry('厂商', movie.makerName.trim()),
    MapEntry('导演', movie.directorName.trim()),
  ];

  return items
      .where((item) => item.value.isNotEmpty)
      .map(
        (item) => Padding(
          padding: EdgeInsets.only(
            bottom: context.appComponentTokens.movieDetailSectionGap,
          ),
          child: Text(
            '${item.key} · ${item.value}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
      )
      .toList(growable: false);
}

class MovieDetailLoadingSkeleton extends StatelessWidget {
  const MovieDetailLoadingSkeleton({super.key, required this.controller});

  final MovieDetailController controller;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final heroHeight = _resolveViewportHeight(context, constraints) * 0.3;
        final availableWidth = _resolveViewportWidth(context, constraints);
        final titleWidth = math.min(240.0, availableWidth * 0.56);
        final movieNumberWidth = math.min(180.0, availableWidth * 0.4);
        final summaryWidth = math.min(520.0, availableWidth * 0.82);
        final labelWidth = math.min(120.0, availableWidth * 0.3);
        return SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                key: const Key('movie-detail-loading-skeleton'),
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _SkeletonBlock(height: 28, width: titleWidth),
                  SizedBox(height: context.appSpacing.lg),
                  _SkeletonBlock(height: heroHeight),
                  SizedBox(height: context.appSpacing.lg),
                  _SkeletonBlock(
                    height:
                        context
                            .appComponentTokens
                            .movieDetailPlotThumbnailHeight,
                  ),
                  SizedBox(
                    height: context.appComponentTokens.movieDetailSectionGap,
                  ),
                  _SkeletonBlock(height: 18, width: movieNumberWidth),
                  SizedBox(height: context.appSpacing.xs),
                  _SkeletonBlock(height: 16, width: summaryWidth),
                  SizedBox(height: context.appSpacing.xs),
                  _SkeletonBlock(height: 18, width: summaryWidth),
                  SizedBox(height: context.appSpacing.xxl),
                  _SkeletonBlock(height: 18, width: labelWidth),
                  SizedBox(height: context.appSpacing.md),
                  const _SkeletonBlock(height: 64),
                  SizedBox(height: context.appSpacing.lg),
                  _SkeletonBlock(height: 18, width: labelWidth),
                  SizedBox(height: context.appSpacing.md),
                  const _SkeletonBlock(height: 96),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class MovieDetailErrorState extends StatelessWidget {
  const MovieDetailErrorState({
    super.key,
    required this.message,
    required this.onRetry,
  });

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

double _resolveViewportHeight(
  BuildContext context,
  BoxConstraints constraints,
) {
  if (constraints.hasBoundedHeight && constraints.maxHeight.isFinite) {
    return constraints.maxHeight;
  }
  return MediaQuery.sizeOf(context).height;
}

double _resolveViewportWidth(BuildContext context, BoxConstraints constraints) {
  if (constraints.hasBoundedWidth && constraints.maxWidth.isFinite) {
    return constraints.maxWidth;
  }
  return MediaQuery.sizeOf(context).width;
}

List<MovieDetailStatItem> buildMovieDetailStatItems(
  BuildContext context,
  MovieDetailDto movie,
) {
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

extension MovieMediaItemIterableX on Iterable<MovieMediaItemDto> {
  MovieMediaItemDto? get firstOrNull {
    for (final item in this) {
      return item;
    }
    return null;
  }
}
