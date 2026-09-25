import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:intl/intl.dart';
import 'package:sakuramedia/core/format/media_timecode.dart';
import 'package:sakuramedia/widgets/base/actions/app_icon_button.dart';
import 'package:sakuramedia/features/clips/data/dto/media_clip_dto.dart';
import 'package:sakuramedia/features/movies/data/dto/detail/movie_detail_dto.dart';
import 'package:sakuramedia/features/movies/data/dto/player/movie_subtitle_dto.dart';
import 'package:sakuramedia/features/movies/data/dto/listing/movie_list_item_dto.dart';
import 'package:sakuramedia/features/movies/presentation/actions/movie_collection_feature_actions.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/actions/app_button.dart';
import 'package:sakuramedia/widgets/base/feedback/app_empty_state.dart';
import 'package:sakuramedia/features/movies/presentation/widgets/detail/movie_actor_wrap.dart';
import 'package:sakuramedia/features/movies/presentation/widgets/detail/movie_detail_bottom_info_bar.dart';
import 'package:sakuramedia/features/movies/presentation/widgets/detail/movie_detail_number_bar.dart';
import 'package:sakuramedia/features/movies/presentation/widgets/detail/movie_detail_hero_card.dart';
import 'package:sakuramedia/features/movies/presentation/widgets/detail/movie_detail_section.dart';
import 'package:sakuramedia/features/movies/presentation/widgets/detail/movie_detail_stat_row.dart';
import 'package:sakuramedia/features/movies/presentation/widgets/detail/movie_detail_title.dart';
import 'package:sakuramedia/features/movies/presentation/widgets/detail/movie_clip_strip.dart';
import 'package:sakuramedia/features/movies/presentation/widgets/detail/movie_media_item_list.dart';
import 'package:sakuramedia/features/movies/presentation/widgets/detail/movie_plot_gallery.dart';
import 'package:sakuramedia/features/movies/presentation/widgets/detail/movie_ranking_list.dart';
import 'package:sakuramedia/features/movies/presentation/widgets/detail/movie_similar_movie_strip.dart';
import 'package:sakuramedia/features/movies/presentation/widgets/detail/movie_subtitle_section.dart';
import 'package:sakuramedia/features/movies/presentation/widgets/detail/movie_tag_wrap.dart';

typedef MovieDetailScrollViewBuilder =
    Widget Function(
      BuildContext context,
      Widget content,
      ScrollPhysics? scrollPhysics,
    );

class MovieDetailPageContent extends StatelessWidget {
  const MovieDetailPageContent({
    this.showSimilarMovies = true,
    super.key,
    required this.movie,
    required this.selectedPreviewKey,
    required this.selectedPreviewUrl,
    required this.isCollection,
    required this.isSubscribed,
    required this.isCollectionUpdating,
    required this.isSubscriptionUpdating,
    required this.selectedMediaId,
    required this.statItems,
    required this.similarMovies,
    required this.isSimilarMoviesLoading,
    required this.onInspectorTap,
    required this.onPlaylistTap,
    required this.onCollectionToggle,
    required this.onMediaSelect,
    this.isDeletingSelectedMedia = false,
    this.onDeleteSelectedMedia,
    this.mediaItemsOverride,
    this.onOpenMediaPointPreview,
    this.onRequestMediaPointMenu,
    this.onPlayTap,
    this.mergePlaybackLabel,
    this.onMergePlaybackTap,
    this.isMergePlaybackLoading = false,
    this.onSubscriptionTap,
    this.onMoreActionsTap,
    this.onActorTap,
    this.onSeriesTap,
    this.onTagTap,
    this.onRequestPlotImageMenu,
    this.onOpenPlotPreview,
    this.similarMoviesErrorMessage,
    this.onRetrySimilarMovies,
    this.onSimilarMovieTap,
    this.clips = const <MediaClipDto>[],
    this.isClipsLoading = false,
    this.clipsErrorMessage,
    this.onRetryClips,
    this.onOpenClipActions,
    this.onPlayClip,
    this.onRenameClip,
    this.onDeleteClip,
    this.onAddClipToCollection,
    this.subtitleItems = const <MovieSubtitleItemDto>[],
    this.isSubtitlesLoading = false,
    this.subtitleErrorMessage,
    this.onRetrySubtitles,
    this.onOpenSubtitle,
    this.contentPadding = EdgeInsets.zero,
    this.bottomInfoBarVariant = MovieDetailBottomInfoBarVariant.desktopCard,
    this.scrollPhysics,
    this.scrollViewBuilder,
    this.isMoreActionsUpdating = false,
    this.isPlayLoading = false,
  });

  final MovieDetailDto movie;
  final List<MovieMediaItemDto>? mediaItemsOverride;
  final String selectedPreviewKey;
  final String? selectedPreviewUrl;
  final bool isCollection;
  final bool isSubscribed;
  final bool isCollectionUpdating;
  final bool isSubscriptionUpdating;
  final bool isMoreActionsUpdating;
  final int? selectedMediaId;
  final List<MovieDetailStatItem> statItems;
  final List<MovieListItemDto> similarMovies;
  final bool isSimilarMoviesLoading;
  final VoidCallback onInspectorTap;
  final VoidCallback onPlaylistTap;
  final VoidCallback? onCollectionToggle;
  final ValueChanged<MovieMediaItemDto> onMediaSelect;
  final bool isDeletingSelectedMedia;
  final ValueChanged<MovieMediaItemDto>? onDeleteSelectedMedia;
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
  final String? mergePlaybackLabel;
  final VoidCallback? onMergePlaybackTap;
  final bool isMergePlaybackLoading;
  final VoidCallback? onSubscriptionTap;
  final Future<void> Function(Offset globalPosition)? onMoreActionsTap;
  final ValueChanged<MovieActorDto>? onActorTap;
  final VoidCallback? onSeriesTap;
  final ValueChanged<MovieTagDto>? onTagTap;
  final Future<void> Function(
    BuildContext context,
    int index,
    Offset globalPosition,
  )?
  onRequestPlotImageMenu;
  final ValueChanged<int>? onOpenPlotPreview;
  final String? similarMoviesErrorMessage;
  final VoidCallback? onRetrySimilarMovies;
  final ValueChanged<MovieListItemDto>? onSimilarMovieTap;
  final List<MediaClipDto> clips;
  final bool isClipsLoading;
  final String? clipsErrorMessage;
  final VoidCallback? onRetryClips;

  /// 点击切片卡：打开动作面板。
  final ValueChanged<MediaClipDto>? onOpenClipActions;

  /// 切片卡悬停播放键：直接播放。
  final ValueChanged<MediaClipDto>? onPlayClip;
  final ValueChanged<MediaClipDto>? onRenameClip;
  final ValueChanged<MediaClipDto>? onDeleteClip;
  final ValueChanged<MediaClipDto>? onAddClipToCollection;
  final List<MovieSubtitleItemDto> subtitleItems;
  final bool isSubtitlesLoading;
  final String? subtitleErrorMessage;
  final Future<void> Function()? onRetrySubtitles;
  final Future<void> Function(MovieSubtitleItemDto item)? onOpenSubtitle;
  final EdgeInsetsGeometry contentPadding;
  final MovieDetailBottomInfoBarVariant bottomInfoBarVariant;
  final ScrollPhysics? scrollPhysics;
  final MovieDetailScrollViewBuilder? scrollViewBuilder;

  /// 播放动作进行中（合并播放探测/拉起外部播放器），透传给 hero 播放按钮显示 loading。
  final bool isPlayLoading;

  final bool showSimilarMovies;

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

          final content = Padding(
            padding: EdgeInsets.only(bottom: scrollBottomPadding),
            child: Padding(
              padding: contentPadding,
              child: _buildDetailBody(context: context, heroHeight: heroHeight),
            ),
          );
          final scrollableContent =
              scrollViewBuilder?.call(context, content, scrollPhysics) ??
              SingleChildScrollView(physics: scrollPhysics, child: content);

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

  MovieMediaProgressDto? get _latestProgress {
    MovieMediaProgressDto? latest;
    for (final media in movie.mediaItems) {
      final progress = media.progress;
      if (progress == null) continue;
      if (latest == null ||
          (progress.lastWatchedAt != null &&
              (latest.lastWatchedAt == null ||
                  progress.lastWatchedAt!.isAfter(latest.lastWatchedAt!)))) {
        latest = progress;
      }
    }
    return latest;
  }

  Widget _buildPlaylistMembership(BuildContext context) {
    final style = resolveAppTextStyle(
      context,
      size: AppTextSize.s12,
      tone: AppTextTone.muted,
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        return Padding(
          padding: EdgeInsets.only(bottom: context.appSpacing.sm),
          child: Wrap(
            spacing: context.appSpacing.sm,
            runSpacing: context.appSpacing.sm,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text('已加入', style: style),
              for (final playlist in movie.playlists.take(2))
                Tooltip(
                  message: playlist.name,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: constraints.maxWidth / 2,
                    ),
                    child: Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: context.appSpacing.sm,
                        vertical: context.appSpacing.xs,
                      ),
                      decoration: BoxDecoration(
                        color: context.appColors.surfaceMuted,
                        borderRadius: context.appRadius.smBorder,
                      ),
                      child: Text(
                        playlist.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: resolveAppTextStyle(
                          context,
                          size: AppTextSize.s12,
                          tone: AppTextTone.secondary,
                        ),
                      ),
                    ),
                  ),
                ),
              if (movie.playlists.length > 2)
                Text('共 ${movie.playlists.length} 个', style: style),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDetailBody({
    required BuildContext context,
    required double heroHeight,
  }) {
    final hoverActions = movieCardHoverFeatureActions(context);
    final progress = _latestProgress;
    final watchLabel = progress == null
        ? null
        : '上次看到 ${formatMediaTimecode(progress.lastPositionSeconds)}';
    final watchedAt = progress?.lastWatchedAt?.toLocal();
    final mediaItems = mediaItemsOverride ?? movie.mediaItems;
    final normalizedMergePlaybackLabel = mergePlaybackLabel?.trim() ?? '';
    final hasMergePlaybackAction = normalizedMergePlaybackLabel.isNotEmpty;
    final isMergePlaybackPrimary = hasMergePlaybackAction && onPlayTap == null;
    final orderedActors = <MovieActorDto>[
      ...movie.actors.where((actor) => actor.isFemale),
      ...movie.actors.where((actor) => !actor.isFemale),
    ];
    final collectionTrigger = TextButton(
      key: const Key('movie-detail-collection-trigger'),
      onPressed: isCollectionUpdating ? null : onCollectionToggle,
      style: ButtonStyle(
        minimumSize: WidgetStateProperty.all(Size.zero),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        foregroundColor: WidgetStateProperty.all(
          Theme.of(context).colorScheme.primary,
        ),
        padding: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.hovered)) {
            return EdgeInsets.symmetric(
              horizontal: context.appSpacing.sm,
              vertical: context.appSpacing.md,
            );
          }
          return EdgeInsets.symmetric(
            horizontal: context.appSpacing.xs,
            vertical: 0,
          );
        }),
      ),
      child: Text(
        isCollection ? '标记单体' : '标记合集',
        style: resolveAppTextStyle(
          context,
          size: AppTextSize.s14,
          weight: AppTextWeight.regular,
          tone: AppTextTone.tertiary,
        ).copyWith(color: Theme.of(context).colorScheme.primary),
      ),
    );

    return Column(
      key: const Key('movie-detail-page'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        MovieDetailTitle(
          title: movie.preferredTitle,
          movieNumber: movie.movieNumber,
        ),
        MovieDetailHeroCard(
          height: heroHeight,
          watchLabel: watchLabel,
          watchTooltip: watchedAt == null
              ? watchLabel
              : '$watchLabel · ${DateFormat('yyyy年M月d日 HH:mm').format(watchedAt)}',
          mainImageKey: selectedPreviewKey,
          mainImageUrl: selectedPreviewUrl,
          heat: movie.heat,
          canPlay: movie.canPlay,
          isSubscribed: isSubscribed,
          isCollection: isCollection,
          onSubscriptionTap: onSubscriptionTap,
          isSubscriptionUpdating: isSubscriptionUpdating,
          onMoreActionsTap: onMoreActionsTap,
          isMoreActionsUpdating: isMoreActionsUpdating,
          isPlayLoading: isPlayLoading,
          onPlayTap: onPlayTap,
        ),
        if (hasMergePlaybackAction) ...[
          SizedBox(height: context.appSpacing.sm),
          AppButton(
            key: const Key('movie-detail-merge-playback-button'),
            label: normalizedMergePlaybackLabel,
            icon: const Icon(Icons.merge_rounded),
            variant: isMergePlaybackPrimary
                ? AppButtonVariant.primary
                : AppButtonVariant.secondary,
            isLoading: isMergePlaybackLoading,
            onPressed: onMergePlaybackTap,
          ),
        ],
        if (movie.plotImages.isNotEmpty) ...[
          SizedBox(height: context.appSpacing.lg),
          MoviePlotGallery(
            plotImages: movie.plotImages,
            onRequestImageMenu: onRequestPlotImageMenu,
            onOpenPreview: onOpenPlotPreview,
          ),
        ],
        SizedBox(height: context.appComponentTokens.movieDetailSectionGap),
        MovieDetailNumberBar(
          movieNumber: movie.movieNumber,
          summary: movie.preferredDescription,
          wantWatchCount: movie.wantWatchCount,
          watchedCount: movie.watchedCount,
          score: movie.score,
          commentCount: movie.commentCount,
          heat: movie.heat,
          scoreNumber: movie.scoreNumber,
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              collectionTrigger,
              SizedBox(width: context.appSpacing.xs),
              AppIconButton(
                key: const Key('movie-detail-playlist-trigger'),
                onPressed: onPlaylistTap,
                icon: Icon(
                  Icons.playlist_add_rounded,
                  size: context.appComponentTokens.iconSizeLg,
                  color: Theme.of(context).colorScheme.primary,
                ),
                tooltip: movie.playlists.isEmpty ? '加入播放列表' : '管理播放列表',
              ),
            ],
          ),
        ),
        if (movie.playlists.isNotEmpty) _buildPlaylistMembership(context),
        ..._buildInlineMetaItems(context, movie, onSeriesTap),
        if (movie.rankings.isNotEmpty)
          MovieDetailSection(
            title: '榜单',
            titleKey: const Key('movie-rankings-title'),
            child: MovieRankingList(rankings: movie.rankings),
          ),
        if (movie.tags.isNotEmpty)
          MovieDetailSection(
            title: '标签',
            child: MovieTagWrap(tags: movie.tags, onTagTap: onTagTap),
          ),
        if (orderedActors.isNotEmpty)
          MovieDetailSection(
            title: '演员',
            child: MovieActorWrap(
              actors: orderedActors,
              onActorTap: onActorTap,
            ),
          ),
        if (mediaItems.isNotEmpty)
          MovieDetailSection(
            title: '媒体源',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                MovieMediaItemList(
                  mediaItems: mediaItems,
                  selectedMediaId: selectedMediaId,
                  onSelect: onMediaSelect,
                  isDeletingSelectedMedia: isDeletingSelectedMedia,
                  onDeleteSelectedMedia: onDeleteSelectedMedia,
                  onOpenPointPreview: onOpenMediaPointPreview,
                  onRequestPointMenu: onRequestMediaPointMenu,
                ),
              ],
            ),
          ),
        if (isSubtitlesLoading ||
            subtitleErrorMessage?.trim().isNotEmpty == true ||
            subtitleItems.isNotEmpty)
          MovieDetailSection(
            title: subtitleItems.isEmpty
                ? '字幕'
                : '字幕 · ${subtitleItems.length}',
            titleKey: const Key('movie-subtitles-title'),
            child: MovieSubtitleSection(
              items: subtitleItems,
              isLoading: isSubtitlesLoading,
              errorMessage: subtitleErrorMessage,
              onRetry: onRetrySubtitles,
              onOpenSubtitle: onOpenSubtitle,
            ),
          ),
        if (isClipsLoading || clipsErrorMessage != null || clips.isNotEmpty)
          MovieDetailSection(
            title: '切片',
            titleKey: const Key('movie-clips-title'),
            child: MovieClipStrip(
              clips: clips,
              isLoading: isClipsLoading,
              errorMessage: clipsErrorMessage,
              onRetry: onRetryClips,
              onOpenClipActions: onOpenClipActions ?? (_) {},
              onPlayClip: onPlayClip ?? (_) {},
              onRenameClip: onRenameClip ?? (_) {},
              onDeleteClip: onDeleteClip ?? (_) {},
              onAddClipToCollection: onAddClipToCollection ?? (_) {},
            ),
          ),
        if (showSimilarMovies && (isSimilarMoviesLoading ||
            similarMoviesErrorMessage?.trim().isNotEmpty == true ||
            similarMovies.isNotEmpty))
          MovieDetailSection(
            title: '相似影片',
            titleKey: const Key('movie-similar-movies-title'),
            child: MovieSimilarMovieStrip(
              movies: similarMovies,
              isLoading: isSimilarMoviesLoading,
              errorMessage: similarMoviesErrorMessage,
              onRetry: onRetrySimilarMovies,
              onMovieTap: onSimilarMovieTap,
              onMovieMenuRequest: (movie, globalPosition) =>
                  requestMovieCollectionMenu(
                    context,
                    movie.movieNumber,
                    globalPosition,
                    isSubscribed: movie.isSubscribed,
                  ),
              onMovieToggleCollectionType:
                  hoverActions.toggleCollectionType,
              onMovieBlacklist: hoverActions.blacklist,
            ),
          ),
      ],
    );
  }
}

List<Widget> _buildInlineMetaItems(
  BuildContext context,
  MovieDetailDto movie,
  VoidCallback? onSeriesTap,
) {
  final items = <_MovieInlineMetaItem>[
    _MovieInlineMetaItem(
      label: '系列',
      value: movie.seriesName.trim(),
      onTap: movie.seriesId == null ? null : onSeriesTap,
    ),
    _MovieInlineMetaItem(label: '厂商', value: movie.makerName.trim()),
    _MovieInlineMetaItem(label: '导演', value: movie.directorName.trim()),
    if (movie.metadataSourceName != null)
      _MovieInlineMetaItem(
        label: '元数据',
        value: movie.javdbId == null
            ? '${movie.metadataSourceName} · 待 JavDB 收录'
            : 'JavDB',
      ),
  ].where((item) => item.value.isNotEmpty).toList(growable: false);

  if (items.isEmpty) {
    return const <Widget>[];
  }

  return <Widget>[
    Padding(
      padding: EdgeInsets.only(
        bottom: context.appComponentTokens.movieDetailSectionGap,
      ),
      child: Column(
        key: const Key('movie-detail-inline-meta-group'),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var index = 0; index < items.length; index++) ...[
            if (index > 0) SizedBox(height: context.appSpacing.sm),
            _MovieInlineMetaRow(item: items[index]),
          ],
        ],
      ),
    ),
  ];
}

class _MovieInlineMetaItem {
  const _MovieInlineMetaItem({
    required this.label,
    required this.value,
    this.onTap,
  });

  final String label;
  final String value;
  final VoidCallback? onTap;
}

class _MovieInlineMetaRow extends StatelessWidget {
  const _MovieInlineMetaRow({required this.item});

  final _MovieInlineMetaItem item;

  @override
  Widget build(BuildContext context) {
    final textStyle = resolveAppTextStyle(
      context,
      size: AppTextSize.s12,
      weight: AppTextWeight.regular,
      tone: AppTextTone.muted,
    );
    final label = '${item.label} · ${item.value}';
    final onTap = item.onTap;
    if (onTap == null) {
      return Text(label, style: textStyle);
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        mouseCursor: SystemMouseCursors.click,
        key: const Key('movie-detail-series-link'),
        onTap: onTap,
        borderRadius: context.appRadius.xsBorder,
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: context.appSpacing.xs,
            vertical: 0,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  label,
                  style: textStyle.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ),
              SizedBox(width: context.appSpacing.xs),
              Icon(
                Icons.chevron_right_rounded,
                size: context.appComponentTokens.iconSizeSm,
                color: Theme.of(context).colorScheme.primary,
              ),
            ],
          ),
        ),
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

List<MovieDetailStatItem> buildMovieDetailStatItems(
  BuildContext context,
  MovieDetailDto movie,
) {
  final releaseLabel = movie.releaseDate == null
      ? '--'
      : DateFormat('yy/MM/dd').format(movie.releaseDate!);
  final durationLabel = movie.durationMinutes > 0
      ? '${movie.durationMinutes} 分钟'
      : '--';
  final scoreLabel = movie.score > 0 ? movie.score.toStringAsFixed(1) : '--';
  final commentCountLabel = movie.commentCount > 0
      ? '${movie.commentCount}'
      : '--';
  final wantWatchCountLabel = movie.wantWatchCount > 0
      ? '${movie.wantWatchCount}'
      : '--';

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
