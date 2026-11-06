import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/core/format/app_date_format.dart';
import 'package:sakuramedia/core/format/app_number_format.dart';
import 'package:sakuramedia/core/format/file_size.dart';
import 'package:sakuramedia/core/format/media_timecode.dart';
import 'package:sakuramedia/features/movies/data/dto/detail/movie_detail_dto.dart';
import 'package:sakuramedia/features/movies/presentation/actions/movie_collection_feature_actions.dart';
import 'package:sakuramedia/features/movies/presentation/pages/shared/movie_detail_view_model.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/interaction/app_interactive_surface.dart';
import 'package:sakuramedia/widgets/base/feedback/app_error_state.dart';
import 'package:sakuramedia/widgets/base/layout/scrolling/app_bottom_safe_area_sliver.dart';
import 'package:sakuramedia/widgets/base/layout/scrolling/app_no_pull_down_scroll_view.dart';
import 'package:sakuramedia/widgets/base/media/images/masked_image.dart';
import 'package:sakuramedia/features/movies/presentation/widgets/detail/movie_actor_section.dart';
import 'package:sakuramedia/features/movies/presentation/widgets/detail/movie_detail_hero_card.dart';
import 'package:sakuramedia/features/movies/presentation/widgets/detail/movie_detail_info_block.dart';
import 'package:sakuramedia/features/movies/presentation/widgets/detail/movie_detail_section.dart';
import 'package:sakuramedia/features/movies/presentation/widgets/detail/movie_clip_strip.dart';
import 'package:sakuramedia/features/movies/presentation/widgets/detail/movie_media_item_list.dart';
import 'package:sakuramedia/features/movies/presentation/widgets/detail/movie_plot_gallery.dart';
import 'package:sakuramedia/features/movies/presentation/widgets/detail/movie_ranking_list.dart';
import 'package:sakuramedia/features/movies/presentation/widgets/detail/movie_similar_movie_strip.dart';
import 'package:sakuramedia/features/movies/presentation/widgets/detail/movie_subtitle_section.dart';
import 'package:sakuramedia/features/movies/presentation/widgets/detail/movie_tag_wrap.dart';
import 'package:sakuramedia/features/playlists/data/dto/playlist_dto.dart';
import 'package:sakuramedia/l10n/app_localizations.dart';

class MovieDetailPageContent extends StatelessWidget {
  /// 正文滚动容器（[AppNoPullDownScrollView]，顶部不可下拉）的测试锚点。
  static const Key scrollViewKey = Key('movie-detail-scroll-view');

  const MovieDetailPageContent({
    super.key,
    required this.data,
    required this.state,
    required this.actions,
    required this.config,
  });

  final MovieDetailViewData data;
  final MovieDetailViewState state;
  final MovieDetailViewActions actions;
  final MovieDetailViewConfig config;

  /// 当前是否真的有封面图：桌面用视口上限加高、信息块上叠只对「有封面」生效，
  /// 没有封面时不为一块纯色占位撑满一屏。
  bool get _hasCover =>
      data.selectedPreviewUrl != null && data.selectedPreviewUrl!.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // 整页模糊背景：封面高斯模糊铺底 + 底色罩一层，保证下方文字可读。
        // 背景固定不随滚动，封面切换时才重绘一次。
        Positioned.fill(
          child: _MovieDetailBackground(
            url: data.selectedPreviewUrl,
            baseColor: config.surfaceColor,
          ),
        ),
        Positioned.fill(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final viewportHeight = _resolveViewportHeight(
                context,
                constraints,
              );
              final heroFit = _resolveHeroFit(constraints);
              final heroHeight = _resolveHeroHeight(
                constraints,
                viewportHeight,
                heroFit,
                hasCover: _hasCover,
              );
              // 顶部继续下拉时页面完全不动（无回弹、无 Android 拉伸），
              // 底部上滑的过卷手感保持平台默认。
              return AppNoPullDownScrollView(
                key: scrollViewKey,
                // 移动子页外壳不吞底部安全区，滚动末尾补等高留白，
                // 最后一块内容不会被 home indicator 压住。
                slivers: <Widget>[
                  SliverPadding(
                    padding: config.contentPadding,
                    sliver: _buildDetailBody(
                      context: context,
                      heroHeight: heroHeight,
                      heroFit: heroFit,
                    ),
                  ),
                  ...bottomSafeAreaSliver(context),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  MovieMediaProgressDto? get _latestProgress {
    MovieMediaProgressDto? latest;
    for (final media in data.movie.mediaItems) {
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
    final l10n = AppLocalizations.of(context);
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
              Text(l10n.moviePagePlaylistAdded, style: style),
              for (final playlist in data.movie.playlists.take(2))
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
              if (data.movie.playlists.length > 2)
                Text(
                  l10n.moviePagePlaylistTotalCount(data.movie.playlists.length),
                  style: style,
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDetailBody({
    required BuildContext context,
    required double heroHeight,
    required BoxFit heroFit,
  }) {
    final hoverActions = movieCardHoverFeatureActions(context);
    final l10n = AppLocalizations.of(context);
    final progress = _latestProgress;
    final watchLabel = progress == null
        ? null
        : l10n.moviePageWatchLabel(
            formatMediaTimecode(progress.lastPositionSeconds),
          );
    final watchedAt = progress?.lastWatchedAt?.toLocal();
    final mediaItems = data.mediaItems;
    final normalizedMergePlaybackLabel = state.mergePlaybackLabel?.trim() ?? '';
    final orderedActors = <MovieActorDto>[
      ...data.movie.actors.where((actor) => actor.isFemale),
      ...data.movie.actors.where((actor) => !actor.isFemale),
    ];

    // 首屏两块（Hero / 信息块）整幅铺满，其余正文区块统一左右留白。
    // 两块常驻构建（都在首帧视口内）；[Key('movie-detail-page')] 挂在盒模型上，
    // 测试里的 getTopLeft 才能取到页面左缘。
    // 首屏两块叠一层：信息块上提 [_desktopHeroInfoOverlapFactor] × Hero 高，
    // 前面一段压在封面下沿（只 PC）。封面高度不变，页面总高随之缩短。
    final infoOverlap = _resolveHeroInfoOverlap(
      heroHeight,
      heroFit,
      hasCover: _hasCover,
    );
    final header = Column(
      key: const Key('movie-detail-page'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Stack(
          children: [
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: heroHeight,
              child: MovieDetailHeroCard(
                height: heroHeight,
                mainImageKey: data.selectedPreviewKey,
                mainImageUrl: data.selectedPreviewUrl,
                heroFit: heroFit,
                veilColor: config.surfaceColor,
              ),
            ),
            Padding(
              padding: EdgeInsets.only(top: heroHeight - infoOverlap),
              child: SizedBox(
                // 撑满可用宽度：Stack 里只有这一个非定位子节点，它决定整块宽度。
                width: double.infinity,
                child: MovieDetailInfoBlock(
                  overlayTitle: _resolveOverlayTitle(data.movie),
                  eyebrow: data.movie.movieNumber,
                  metaItems: _resolveMetaItems(context, data.movie),
                  fileSizeLabel: _resolveFileSizeLabel(
                    mediaItems,
                    data.selectedMediaId,
                  ),
                  watchLabel: watchLabel,
                  watchTooltip: watchedAt == null
                      ? watchLabel
                      : l10n.moviePageWatchLabelWithDate(
                          watchLabel ?? '',
                          formatAppDateTime(watchedAt),
                        ),
                  isSubscribed: state.isSubscribed,
                  onSubscriptionTap: actions.onSubscriptionTap,
                  isSubscriptionUpdating: state.isSubscriptionUpdating,
                  isFavorite: data.movie.playlists.any(
                    (playlist) => playlist.kind == PlaylistKind.favorites,
                  ),
                  onFavoriteTap: actions.onFavoriteTap,
                  isFavoriteUpdating: state.isFavoriteUpdating,
                  onPlaylistTap: actions.onPlaylistTap,
                  playlistTooltip: data.movie.playlists.isEmpty
                      ? l10n.moviePagePlaylistAddAction
                      : l10n.moviePagePlaylistManageAction,
                  onMoreActionsTap: actions.onMoreActionsTap,
                  isMoreActionsUpdating: state.isMoreActionsUpdating,
                  isPlayLoading: state.isPlayLoading,
                  onPlayTap: actions.onPlayTap,
                  mergePlaybackLabel: normalizedMergePlaybackLabel.isEmpty
                      ? null
                      : normalizedMergePlaybackLabel,
                  onMergePlaybackTap: actions.onMergePlaybackTap,
                  isMergePlaybackLoading: state.isMergePlaybackLoading,
                  onInspectorPaneTap: actions.onInspectorPaneTap,
                  ratingPanel: config.ratingPanel,
                ),
              ),
            ),
          ],
        ),
      ],
    );

    final sections = <Widget>[
      if (data.movie.plotImages.isNotEmpty) ...[
        SizedBox(height: context.appSpacing.lg),
        MoviePlotGallery(
          plotImages: data.movie.plotImages,
          onRequestImageMenu: actions.onRequestPlotImageMenu,
          onOpenPreview: actions.onOpenPlotPreview,
        ),
      ],
      SizedBox(height: context.appComponentTokens.movieDetailSectionGap),
      if (data.movie.preferredDescription.isNotEmpty)
        Padding(
          padding: EdgeInsets.only(
            bottom: context.appComponentTokens.movieDetailSectionGap,
          ),
          child: Text(
            data.movie.preferredDescription,
            key: const Key('movie-detail-summary'),
            style: resolveAppTextStyle(
              context,
              size: AppTextSize.s14,
              weight: AppTextWeight.regular,
              tone: AppTextTone.secondary,
            ),
          ),
        ),
      if (data.movie.playlists.isNotEmpty) _buildPlaylistMembership(context),
      ..._buildInlineMetaItems(context, data.movie, actions.onSeriesTap),
      if (data.movie.rankings.isNotEmpty)
        MovieDetailSection(
          title: l10n.moviePageSectionRankings,
          titleKey: const Key('movie-rankings-title'),
          child: MovieRankingList(rankings: data.movie.rankings),
        ),
      if (data.movie.tags.isNotEmpty)
        MovieDetailSection(
          title: l10n.moviePageSectionTags,
          child: MovieTagWrap(
            tags: data.movie.tags,
            onTagTap: actions.onTagTap,
          ),
        ),
      MovieActorSection(
        actors: orderedActors,
        isActorsManuallyManaged: data.movie.isActorsManuallyManaged,
        onActorTap: actions.onActorTap,
        actorActions: actions.actorActions,
      ),
      if (mediaItems.isNotEmpty)
        MovieDetailSection(
          title: l10n.moviePageSectionMediaSources,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              MovieMediaItemList(
                mediaItems: mediaItems,
                selectedMediaId: data.selectedMediaId,
                onSelect: actions.onMediaSelect,
                isDeletingSelectedMedia: state.isDeletingSelectedMedia,
                onDeleteSelectedMedia: actions.onDeleteSelectedMedia,
                onEditMediaTags: actions.onEditMediaTags,
                onOpenPointPreview: actions.onOpenMediaPointPreview,
                onRequestPointMenu: actions.onRequestMediaPointMenu,
              ),
            ],
          ),
        ),
      if (state.isSubtitlesLoading ||
          state.subtitleErrorMessage?.trim().isNotEmpty == true ||
          data.subtitleItems.isNotEmpty)
        MovieDetailSection(
          title: data.subtitleItems.isEmpty
              ? l10n.moviePageSectionSubtitles
              : l10n.moviePageSectionSubtitlesCount(data.subtitleItems.length),
          titleKey: const Key('movie-subtitles-title'),
          child: MovieSubtitleSection(
            items: data.subtitleItems,
            isLoading: state.isSubtitlesLoading,
            errorMessage: state.subtitleErrorMessage,
            onRetry: actions.onRetrySubtitles,
            onOpenSubtitle: actions.onOpenSubtitle,
          ),
        ),
      if (state.isClipsLoading ||
          state.clipsErrorMessage != null ||
          data.clips.isNotEmpty)
        MovieDetailSection(
          title: l10n.moviePageSectionClips,
          titleKey: const Key('movie-clips-title'),
          child: MovieClipStrip(
            clips: data.clips,
            isLoading: state.isClipsLoading,
            errorMessage: state.clipsErrorMessage,
            onRetry: actions.onRetryClips,
            onOpenClipActions: actions.onOpenClipActions ?? (_) {},
            onPlayClip: actions.onPlayClip ?? (_) {},
            onRenameClip: actions.onRenameClip ?? (_) {},
            onDeleteClip: actions.onDeleteClip ?? (_) {},
            onAddClipToCollection: actions.onAddClipToCollection ?? (_) {},
          ),
        ),
      if (config.showSimilarMovies &&
          (state.isSimilarMoviesLoading ||
              state.similarMoviesErrorMessage?.trim().isNotEmpty == true ||
              data.similarMovies.isNotEmpty))
        MovieDetailSection(
          title: l10n.moviePageSectionSimilarMovies,
          titleKey: const Key('movie-similar-movies-title'),
          child: MovieSimilarMovieStrip(
            movies: data.similarMovies,
            isLoading: state.isSimilarMoviesLoading,
            errorMessage: state.similarMoviesErrorMessage,
            onRetry: actions.onRetrySimilarMovies,
            onMovieTap: actions.onSimilarMovieTap,
            onMovieMenuRequest: (movie, globalPosition) =>
                requestMovieCollectionMenu(
                  context,
                  movie.movieNumber,
                  globalPosition,
                  isSubscribed: movie.isSubscribed,
                ),
            onMovieToggleCollectionType: hoverActions.toggleCollectionType,
            onMovieBlacklist: hoverActions.blacklist,
          ),
        ),
    ];

    return SliverMainAxisGroup(
      slivers: <Widget>[
        SliverToBoxAdapter(child: header),
        // 正文区块按需构建：详情区块多、每块都带图（剧照 / 演员头像 / 媒体缩略图 /
        // 切片 / 相似影片），急切建整页会让「进入详情页」的第一帧变成几十毫秒的
        // 大帧；交给 [SliverList.builder] 后首帧只建首屏需要的部分，屏幕外的图
        // 也不再提前解析 provider。
        SliverPadding(
          padding: EdgeInsets.symmetric(horizontal: context.appSpacing.lg),
          sliver: SliverList.builder(
            itemCount: sections.length,
            itemBuilder: (context, index) => sections[index],
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
  final l10n = AppLocalizations.of(context);
  final items = <_MovieInlineMetaItem>[
    _MovieInlineMetaItem(
      label: l10n.moviePageMetaSeries,
      value: movie.seriesName.trim(),
      onTap: movie.seriesId == null ? null : onSeriesTap,
    ),
    if (movie.metadataSourceName != null)
      _MovieInlineMetaItem(
        label: l10n.moviePageMetaMetadata,
        value: movie.javdbId == null
            ? l10n.moviePageMetaNotIndexed(movie.metadataSourceName!)
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
      child: AppInteractiveSurface(
        key: const Key('movie-detail-series-link'),
        onTap: onTap,
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

/// Hero 前景图的填充方式：**跟随布局宽窄**，而不是跟随平台或页面。
///
/// 宽布局（≥ [MovieDetailInfoBlock.wideBreakpoint]，桌面壳层与平板都是）走
/// [BoxFit.contain]：完整显示不裁切，并启用「信息块压封面下沿」；窄布局
/// （手机、窄窗口）走 [BoxFit.cover]：沉浸全幅铺满裁切。
BoxFit _resolveHeroFit(BoxConstraints constraints) {
  final maxWidth = constraints.maxWidth;
  final isWide =
      !maxWidth.isFinite || maxWidth >= MovieDetailInfoBlock.wideBreakpoint;
  return isWide ? BoxFit.contain : BoxFit.cover;
}

/// Hero 高度。
///
/// 桌面完整显示（`contain`）且有封面时取视口高 × [MovieDetailHeroCard.desktopViewportHeightFactor]；
/// 没有封面时不值得为一块纯色占位撑满一屏，保持固定高度配方。
/// 移动沉浸全幅（`cover`）保持窄屏配方，取宽 × 0.72（260~380，纯照片区）；
/// 宽度无界时退回视口高 × 0.42。
double _resolveHeroHeight(
  BoxConstraints constraints,
  double viewportHeight,
  BoxFit fit, {
  required bool hasCover,
}) {
  final maxWidth = constraints.maxWidth;
  if (maxWidth.isFinite && maxWidth > 0) {
    if (maxWidth >= MovieDetailInfoBlock.wideBreakpoint) {
      if (fit == BoxFit.contain && hasCover) {
        return viewportHeight * MovieDetailHeroCard.desktopViewportHeightFactor;
      }
      return (maxWidth * 0.36).clamp(300.0, 440.0).toDouble();
    }
    return (maxWidth * 0.72).clamp(260.0, 380.0).toDouble();
  }
  return (viewportHeight * 0.42).clamp(260.0, 440.0).toDouble();
}

/// 首屏信息块压在封面下沿的比例（只桌面 / PC）：基数是 Hero 高度。
///
/// 压的位置落在封面的「底部化开带」里：封面在这一带由实到透，压上去的文字底下
/// 只剩一层淡淡的封面颜色（化开带高度 = `Hero高 × 0.28 + 56`），标题和按钮这时
/// 可读，也就不需要额外叠渐变遮罩。取比例而不是固定像素：改
/// [MovieDetailHeroCard.desktopViewportHeightFactor] 时，压的深浅不会跟着变。
///
/// 0.10 ≈ 压在封面下部十分之一处（封面高 490 时约 49px）；调小 → 只把标题
/// 和最上面一排按钮压上去；调大 → 更靠上、压在更实的封面上（要么同时调大
/// [MovieDetailHeroCard.meltBandFactor]，要么叠一层渐变遮罩）；调 0 → 回到
///「信息块在封面下方」的老样子。移动端（沉浸全幅）不叠。
const double _desktopHeroInfoOverlapFactor = 0.10;

/// 见 [_desktopHeroInfoOverlapFactor]。没有封面（骨架 / 该影片无图）时不叠；
/// 上限夹到 Hero 高度，避免比例调大后信息块被提到封面之上。
double _resolveHeroInfoOverlap(
  double heroHeight,
  BoxFit fit, {
  required bool hasCover,
}) {
  if (fit != BoxFit.contain || !hasCover) {
    return 0;
  }
  return (heroHeight * _desktopHeroInfoOverlapFactor).clamp(0.0, heroHeight);
}

/// 压在封面上的标题：番号由信息块顶部的 eyebrow 单独承载，这里只返回标题；
/// 标题为空或与番号相同时返回空串，避免重复。
String _resolveOverlayTitle(MovieDetailDto movie) {
  final number = movie.movieNumber.trim();
  final title = movie.preferredTitle.trim();
  if (title.isEmpty || title == number) {
    return '';
  }
  return title;
}

/// 标题下的元信息段：评分｜评论数｜想看｜看过｜热度｜上映日期｜时长｜厂商｜导演，
/// 有值的段才出现（零值/空串隐藏）。
List<MovieDetailMetaItem> _resolveMetaItems(
  BuildContext context,
  MovieDetailDto movie,
) {
  final colors = context.appColors;
  final l10n = AppLocalizations.of(context);
  return [
    if (movie.score > 0)
      MovieDetailMetaItem(
        icon: Icons.star_outline_rounded,
        iconColor: colors.movieDetailScoreIcon,
        text: movie.score.toStringAsFixed(1),
      ),
    if (movie.commentCount > 0)
      MovieDetailMetaItem(
        icon: Icons.chat_bubble_outline_rounded,
        iconColor: colors.movieDetailCommentCountIcon,
        text: formatAppCount(movie.commentCount),
      ),
    if (movie.wantWatchCount > 0)
      MovieDetailMetaItem(
        text: l10n.moviePageMetaWantWatch(movie.wantWatchCount),
      ),
    if (movie.watchedCount > 0)
      MovieDetailMetaItem(text: l10n.moviePageMetaWatched(movie.watchedCount)),
    if (movie.heat > 0)
      MovieDetailMetaItem(
        icon: Icons.local_fire_department_rounded,
        iconColor: colors.movieDetailHeatIcon,
        text: formatAppCompactCount(movie.heat),
      ),
    if (movie.releaseDate != null)
      MovieDetailMetaItem(
        text: l10n.moviePageMetaReleased(formatAppDate(movie.releaseDate!)),
      ),
    if (movie.durationMinutes > 0)
      MovieDetailMetaItem(
        icon: Icons.schedule_outlined,
        iconColor: colors.movieDetailDurationIcon,
        text: l10n.moviePageMetaDuration(movie.durationMinutes),
      ),
    if (movie.makerName.trim().isNotEmpty)
      MovieDetailMetaItem(
        text: l10n.moviePageMetaStudio(movie.makerName.trim()),
      ),
    if (movie.directorName.trim().isNotEmpty)
      MovieDetailMetaItem(
        text: l10n.moviePageMetaDirector(movie.directorName.trim()),
      ),
  ];
}

/// 右列文件大小：选中媒体的文件大小，无选中/大小为 0 时不显示。
String? _resolveFileSizeLabel(
  List<MovieMediaItemDto> mediaItems,
  int? selectedMediaId,
) {
  if (selectedMediaId == null) return null;
  for (final item in mediaItems) {
    if (item.mediaId == selectedMediaId) {
      return item.fileSizeBytes > 0 ? formatFileSize(item.fileSizeBytes) : null;
    }
  }
  return null;
}

/// 整页底座：封面假模糊铺底 + 底色罩一层。
/// 配方引用 [MovieDetailVeil]，与 Hero 底座严格同值，底边相接无分割。
///
/// 无封面时退回纯底色，保证加载态/空态不断层。
class _MovieDetailBackground extends StatelessWidget {
  const _MovieDetailBackground({required this.url, required this.baseColor});

  final String? url;

  /// 桌面传 surfaceElevated、移动传 surfaceCard：遮罩底色跟随各自主题。
  final Color baseColor;

  @override
  Widget build(BuildContext context) {
    if (url == null || url!.isEmpty) {
      return ColoredBox(color: baseColor);
    }
    return Stack(
      fit: StackFit.expand,
      children: [
        // 不透明打底：沉浸页的壳是透明的，底座必须自己全程不透出下一页。
        ColoredBox(color: baseColor),
        // 假模糊（配方见 [MovieDetailVeil.backgroundDecodeWidth]）：小图放大即糊，
        // 不再实时高斯 + 放大圈，也就没有模糊边缘回透与图层画出页面矩形。
        MaskedImage(
          url: url!,
          fit: BoxFit.cover,
          alignment: Alignment.center,
          memCacheWidth: MovieDetailVeil.backgroundDecodeWidth,
          filterQuality: FilterQuality.high,
          // 占位与回退底色同色；解码完成后直接显示（罩了重 veil，不再单独淡入，
          // 避免与前景图两次先后闪烁）。
          placeholderColor: baseColor,
          animateReveal: false,
        ),
        ColoredBox(
          color: baseColor.withValues(
            alpha: MovieDetailVeil.veilAlphaFor(Theme.of(context).brightness),
          ),
        ),
      ],
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
    return AppErrorState(
      title: AppLocalizations.of(context).baseActionFailed,
      message: message,
      onRetry: onRetry,
    );
  }
}
