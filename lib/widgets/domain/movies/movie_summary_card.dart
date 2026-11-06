import 'dart:async';

import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/core/platform/haptic_feedback.dart';
import 'package:sakuramedia/features/movies/data/dto/listing/movie_list_item_dto.dart';
import 'package:sakuramedia/features/movies/presentation/actions/movie_playback_launcher.dart';
import 'package:sakuramedia/l10n/app_localizations.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/interaction/app_cover_hover_info.dart';
import 'package:sakuramedia/widgets/base/interaction/app_interactive_surface.dart';
import 'package:sakuramedia/widgets/base/layout/cards/app_cover_card.dart';
import 'package:sakuramedia/widgets/base/layout/badges/app_media_badge.dart';
import 'package:sakuramedia/widgets/base/media/images/app_cover_bottom_shade.dart';
import 'package:sakuramedia/widgets/base/media/images/app_image_action_trigger.dart';
import 'package:sakuramedia/widgets/base/media/images/masked_image.dart';
import 'package:sakuramedia/widgets/domain/movies/subscription_heart_badge.dart';

/// 影片摘要卡：整卡即封面，与全站封面卡片共用同一套悬停披露范式。
///
/// - 收起态：番号（+ 推荐理由）、排名徽标压在底部渐变上常显；触摸端没有
///   hover，停留在这层；排名只在这层显示；
/// - 桌面悬停：底部渐显压暗层（180ms ease-out），标题/时长/日期与整行动作
///   （播放 / 订阅 / 标记合集-单体 / 屏蔽影片）淡入，收起态主键层（含排名徽标）
///   淡出；系统开启
///   「减弱动态效果」时退化为瞬时切换；
/// - 参数与全站封面卡一致：`lg` 圆角、`surfaceCard` 底色、常驻 1px 边框与常驻
///   卡片阴影；按下反馈与 [AppInteractiveSurface] 一致（整体变淡 0.7）。
///
/// 右键与长按打开影片操作菜单。
class MovieSummaryCard extends StatelessWidget {
  const MovieSummaryCard({
    super.key,
    required this.movie,
    this.rank,
    this.secondaryLabel,
    this.trailingLabel,
    this.onTap,
    this.onRequestMenu,
    this.onSubscriptionTap,
    this.onToggleCollectionType,
    this.onBlacklist,
    this.isSubscriptionUpdating = false,
    this.selectionMode = false,
    this.isSelected = false,
    this.onSelectedChanged,
  });

  final MovieListItemDto movie;
  final int? rank;
  final String? secondaryLabel;

  /// 收起态底部番号行右侧的补充文案（如「总分 4.0」）；null 时不显示。
  final String? trailingLabel;
  final VoidCallback? onTap;
  final ValueChanged<Offset>? onRequestMenu;
  final VoidCallback? onSubscriptionTap;

  /// 悬停动作行的「标记为合集 / 单体」；为 `null` 时不显示该按钮。
  final VoidCallback? onToggleCollectionType;

  /// 悬停动作行的「屏蔽影片」；为 `null` 或影片已订阅（不可屏蔽）时不显示。
  final VoidCallback? onBlacklist;
  final bool isSubscriptionUpdating;

  /// 选择模式开关：为 true 时卡片进入多选态——外圈换选中描边、叠勾选徽标、
  /// 屏蔽 [onRequestMenu] / [onSubscriptionTap]，点击整卡切换选中。
  final bool selectionMode;
  final bool isSelected;
  final ValueChanged<bool>? onSelectedChanged;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final componentTokens = context.appComponentTokens;
    final spacing = context.appSpacing;
    final handlesSubscriptionTapAtCardLevel =
        !selectionMode &&
        onSubscriptionTap != null &&
        (onTap != null || onRequestMenu != null);
    final showCluster = !selectionMode;
    final showHeat = movie.heat > 0;

    final card = AppCoverCard(
      key: Key('movie-summary-card-${movie.movieNumber}'),
      coverAspectRatio: componentTokens.movieCardAspectRatio,
      hoverEnabled: !selectionMode,
      selectionMode: selectionMode,
      isSelected: isSelected,
      cover: _MovieCover(
        movieNumber: movie.movieNumber,
        thinCoverImage: movie.thinCoverImage,
        coverImage: movie.coverImage,
      ),
      collapsedOverlay: _buildCollapsedOverlay(context),
      infoBuilder: (context) => _buildHoverInfo(context),
      overlaysBuilder: (context, constraints) {
        final wrapHeat =
            showHeat && _shouldWrapHeat(context, constraints.maxWidth);
        return [
          // 选择模式下屏蔽订阅心/播放态角标，避免手势冲突与信息噪音。
          if (showCluster)
            Positioned(
              top: spacing.xs,
              left: spacing.xs,
              child: Wrap(
                spacing: spacing.xs,
                runSpacing: spacing.xs,
                children: [
                  IgnorePointer(
                    ignoring: handlesSubscriptionTapAtCardLevel,
                    child: SubscriptionHeartBadge(
                      key: Key(
                        'movie-summary-card-subscription-${movie.movieNumber}',
                      ),
                      loadingKey: Key(
                        'movie-summary-card-subscription-loading-${movie.movieNumber}',
                      ),
                      isSubscribed: movie.isSubscribed,
                      isUpdating: isSubscriptionUpdating,
                      onTap: handlesSubscriptionTapAtCardLevel
                          ? null
                          : onSubscriptionTap,
                    ),
                  ),
                  if (_showPlayableBadge)
                    _StatusBadge(
                      key: Key(
                        'movie-summary-card-status-playable-${movie.movieNumber}',
                      ),
                      icon: Icons.play_arrow_rounded,
                      iconColor: context.appTextPalette.onMedia,
                      background: colors.movieCardPlayableBadgeBackground,
                    ),
                  if (_showResolutionBadge)
                    _ResolutionBadge(
                      movie: movie,
                      movieNumber: movie.movieNumber,
                    ),
                ],
              ),
            ),
          // 卡片放不下时热度折到下一行，避免压住左上角角标。
          if (showHeat)
            Positioned(
              top: wrapHeat
                  ? spacing.xs * 2 + componentTokens.movieCardStatusBadgeSize
                  : spacing.xs,
              left: wrapHeat ? spacing.xs : null,
              right: wrapHeat ? null : spacing.xs,
              child: _HeatBadge(
                movieNumber: movie.movieNumber,
                heat: movie.heat,
              ),
            ),
        ];
      },
    );

    if (selectionMode) {
      return AppInteractiveSurface(
        key: Key('movie-summary-card-checkbox-${movie.movieNumber}'),
        enabled: onSelectedChanged != null,
        onTap: () => onSelectedChanged?.call(!isSelected),
        child: card,
      );
    }
    if (onTap == null && onRequestMenu == null) {
      return card;
    }
    return AppImageActionTrigger(
      onTap: handlesSubscriptionTapAtCardLevel ? null : onTap,
      onTapAt: handlesSubscriptionTapAtCardLevel
          ? (localPosition) {
              final hitPadding =
                  (componentTokens.subscriptionHeartHitSize -
                      componentTokens.movieCardStatusBadgeSize) /
                  2;
              final hitExtent =
                  spacing.xs +
                  componentTokens.movieCardStatusBadgeSize +
                  hitPadding;
              if (localPosition.dx <= hitExtent &&
                  localPosition.dy <= hitExtent) {
                if (!isSubscriptionUpdating) {
                  triggerSelectionHaptic();
                  onSubscriptionTap!();
                }
              } else {
                onTap?.call();
              }
            }
          : null,
      onRequestMenu: onRequestMenu,
      child: card,
    );
  }

  /// 收起态主键层：番号（+ 推荐理由）、排名徽标压在底部渐变上常显；
  /// 悬停展开时由 [AppCoverHoverInfo] 淡出，信息在悬停面板里继续提供。
  Widget _buildCollapsedOverlay(BuildContext context) {
    final spacing = context.appSpacing;
    final number = Text(
      movie.movieNumber,
      key: Key('movie-summary-card-number-${movie.movieNumber}'),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: resolveCoverOverlayTextStyle(
        context,
        size: AppTextSize.s12,
        weight: AppTextWeight.semibold,
      ),
    );
    final Widget info;
    // 推荐理由（如「热门：某某女优」）在触摸端没有悬停可触发，常显为第二行，
    // 否则移动端会彻底看不到它。
    if (secondaryLabel case final label?) {
      info = Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          number,
          SizedBox(height: spacing.xs / 2),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: resolveCoverOverlayTextStyle(
              context,
              size: AppTextSize.s10,
              opacity: 0.72,
            ),
          ),
        ],
      );
    } else {
      info = number;
    }
    return Stack(
      fit: StackFit.expand,
      children: [
        const AppCoverBottomShade(),
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              spacing.md,
              spacing.sm,
              spacing.md,
              spacing.sm + spacing.xs / 2,
            ),
            child: Row(
              children: [
                Expanded(child: info),
                if (trailingLabel case final label?) ...[
                  SizedBox(width: spacing.sm),
                  Text(
                    label,
                    key: Key(
                      'movie-summary-card-trailing-${movie.movieNumber}',
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: resolveCoverOverlayTextStyle(
                      context,
                      size: AppTextSize.s10,
                      opacity: 0.72,
                    ),
                  ),
                ],
                if (rank case final rank?) ...[
                  SizedBox(width: spacing.sm),
                  _RankBadge(rank: rank, movieNumber: movie.movieNumber),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// 悬停面板：番号行（番号 + 行尾时长·日期）、推荐理由、标题（两行）
  /// 与动作按钮；排名只在收起态显示，这里不再重复；
  /// 与全站封面卡片共用同一套底部披露层。
  Widget _buildHoverInfo(BuildContext context) {
    final spacing = context.appSpacing;
    final l10n = AppLocalizations.of(context);
    final showBadges = !selectionMode;
    final actions = <Widget>[
      // 播放是这一层的主操作，用白底实心；选择模式与不可播放时不出。
      if (showBadges && movie.canPlay)
        AppCoverHoverActionButton(
          key: Key('movie-summary-card-play-${movie.movieNumber}'),
          icon: Icons.play_arrow_rounded,
          primary: true,
          tooltip: l10n.widgetMoviePlay,
          onTap: () => _handlePlay(context),
        ),
      if (onSubscriptionTap != null)
        AppCoverHoverActionButton(
          key: Key(
            'movie-summary-card-subscription-action-${movie.movieNumber}',
          ),
          icon: movie.isSubscribed
              ? Icons.favorite_rounded
              : Icons.favorite_border_rounded,
          tooltip: movie.isSubscribed
              ? l10n.widgetMovieUnsubscribe
              : l10n.widgetMovieSubscribeMovie,
          onTap: isSubscriptionUpdating ? null : onSubscriptionTap,
        ),
      if (onToggleCollectionType != null)
        AppCoverHoverActionButton(
          key: Key('movie-summary-card-collection-type-${movie.movieNumber}'),
          icon: Icons.category_outlined,
          tooltip: l10n.widgetMovieToggleCollectionType,
          onTap: onToggleCollectionType,
        ),
      // 已订阅影片不可屏蔽，与右键菜单的显隐规则一致。
      if (onBlacklist != null && !movie.isSubscribed)
        AppCoverHoverActionButton(
          key: Key('movie-summary-card-blacklist-${movie.movieNumber}'),
          icon: Icons.block_rounded,
          tooltip: l10n.widgetMovieBlacklistMovie,
          onTap: onBlacklist,
        ),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Text(
              movie.movieNumber,
              key: Key('movie-summary-card-number-${movie.movieNumber}'),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: resolveCoverOverlayTextStyle(
                context,
                size: AppTextSize.s12,
                weight: AppTextWeight.semibold,
              ),
            ),
            SizedBox(width: spacing.xs),
            // 时长占剩余宽度：标准卡下完整显示，窄卡不够时尾部 ellipsis，
            // 永不把 Row 撑爆（见 thin-cover 回归测试）。
            Expanded(
              child: Text(
                _metaLine(movie, l10n),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: resolveCoverOverlayTextStyle(
                  context,
                  size: AppTextSize.s10,
                  opacity: 0.64,
                ),
              ),
            ),
          ],
        ),
        if (secondaryLabel case final label?) ...[
          SizedBox(height: spacing.xs / 2),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: resolveCoverOverlayTextStyle(
              context,
              size: AppTextSize.s10,
              opacity: 0.72,
            ),
          ),
        ],
        SizedBox(height: spacing.xs / 2),
        Text(
          movie.title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: resolveCoverOverlayTextStyle(
            context,
            size: AppTextSize.s12,
            opacity: 0.78,
          ),
        ),
        if (actions.isNotEmpty) ...[
          SizedBox(height: spacing.xs),
          AppCoverHoverActionBar(actions: actions),
        ],
      ],
    );
  }

  /// 顶部一行放不下左上角角标与右上角热度时，热度折到下一行。
  bool _shouldWrapHeat(BuildContext context, double cardWidth) {
    final spacing = context.appSpacing;
    final tokens = context.appComponentTokens;
    final heatText = TextPainter(
      text: TextSpan(
        text: _formatMovieHeat(movie.heat),
        style: resolveCoverOverlayTextStyle(context, size: AppTextSize.s10),
      ),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
    )..layout();
    final heatWidth =
        spacing.sm * 2 + tokens.iconSize3xs + spacing.xs + heatText.width + 2;
    heatText.dispose();
    final statusWidth =
        tokens.movieCardStatusBadgeSize +
        (_showPlayableBadge
            ? spacing.xs + tokens.movieCardStatusBadgeSize
            : 0) +
        (_showResolutionBadge
            ? spacing.xs + spacing.sm + tokens.movieCardStatusBadgeSize
            : 0);
    return statusWidth + heatWidth + spacing.xs * 3 > cardWidth;
  }

  /// 可播放标：只有在没有清晰度标时才画。清晰度标只在存在有效媒体时出现，
  /// 而有效媒体即 `canPlay`（见 `MovieListItemDto.maxMediaWidth` 的解析与后端
  /// `playable_exists_expression`），4K/8K 卡上再画播放标是重复信息。
  bool get _showPlayableBadge =>
      !selectionMode && movie.canPlay && movie.maxMediaWidth < 3840;

  /// 清晰度标：有效媒体最高宽度 ≥7680 为 8K、≥3840 为 4K 档。
  bool get _showResolutionBadge =>
      !selectionMode && movie.maxMediaWidth >= 3840;

  /// 播放：走统一播放入口，并把当前路由作为应用内播放页的返回落点。
  void _handlePlay(BuildContext context) {
    unawaited(
      launchMoviePlayback(
        context,
        movieNumber: movie.movieNumber,
        inAppFallbackPath: _currentLocationOrNull(context),
      ),
    );
  }

  /// 应用内播放页的返回落点：当前路由。拿不到路由（部分 widget 测试）时返回 null，
  /// [launchMoviePlayback] 会退回到该影片的详情页。
  String? _currentLocationOrNull(BuildContext context) {
    try {
      return GoRouterState.of(context).uri.toString();
    } on Object {
      return null;
    }
  }
}

/// 清晰度胶囊：毛玻璃底 + 4K/8K 粗体字，与订阅心同排（这种情况下不再画播放标）。
class _ResolutionBadge extends StatelessWidget {
  const _ResolutionBadge({required this.movie, required this.movieNumber});

  final MovieListItemDto movie;
  final String movieNumber;

  @override
  Widget build(BuildContext context) {
    final componentTokens = context.appComponentTokens;
    final spacing = context.appSpacing;
    return IgnorePointer(
      child: AppMediaBadge(
        key: Key('movie-summary-card-resolution-$movieNumber'),
        label: movie.maxMediaWidth >= 7680 ? '8K' : '4K',
        width: componentTokens.movieCardStatusBadgeSize + spacing.sm,
        height: componentTokens.movieCardStatusBadgeSize,
        padding: EdgeInsets.zero,
        size: AppMediaBadgeSize.prominent,
      ),
    );
  }
}

/// 右上角热度胶囊：火焰图标 + 格式化数值。
class _HeatBadge extends StatelessWidget {
  const _HeatBadge({required this.movieNumber, required this.heat});

  final String movieNumber;
  final int heat;

  @override
  Widget build(BuildContext context) {
    return AppMediaBadge(
      key: Key('movie-summary-card-heat-$movieNumber'),
      labelKey: Key('movie-summary-card-heat-text-$movieNumber'),
      label: _formatMovieHeat(heat),
      leading: Icon(
        Icons.local_fire_department_rounded,
        color: context.appColors.movieDetailHeatIcon,
      ),
    );
  }
}

/// 圆底状态角标（当前只用于可播放标记）。
class _StatusBadge extends StatelessWidget {
  const _StatusBadge({
    super.key,
    required this.icon,
    required this.iconColor,
    required this.background,
  });

  final IconData icon;
  final Color iconColor;
  final Color background;

  @override
  Widget build(BuildContext context) {
    final componentTokens = context.appComponentTokens;

    return Container(
      width: componentTokens.movieCardStatusBadgeSize,
      height: componentTokens.movieCardStatusBadgeSize,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: background,
        borderRadius: context.appRadius.pillBorder,
      ),
      child: Icon(icon, size: componentTokens.iconSizeXl, color: iconColor),
    );
  }
}

String _metaLine(MovieListItemDto movie, AppLocalizations l10n) {
  final date = movie.releaseDate;
  final datePart = date == null
      ? ''
      : '${date.year}.${date.month.toString().padLeft(2, '0')}.'
            '${date.day.toString().padLeft(2, '0')}';
  final duration = l10n.durationMinutes(movie.durationMinutes);
  if (datePart.isEmpty) {
    return duration;
  }
  return l10n.widgetMovieDurationWithDate(duration, datePart);
}

String _formatMovieHeat(int heat) {
  if (heat < 1000) {
    return '$heat';
  }

  final valueInK = heat / 1000;
  final fixed = valueInK.toStringAsFixed(1);
  final trimmed = fixed.endsWith('.0')
      ? fixed.substring(0, fixed.length - 2)
      : fixed;
  return '${trimmed}k';
}

class _RankBadge extends StatelessWidget {
  const _RankBadge({required this.rank, required this.movieNumber});

  final int rank;
  final String movieNumber;

  @override
  Widget build(BuildContext context) {
    return AppMediaBadge(
      key: Key('movie-summary-card-rank-$movieNumber'),
      label: '#$rank',
    );
  }
}

/// 封面按「图源 + 番号」择优渲染:FC2- 番号用主封面 + [BoxFit.contain](其封面多为横图,
/// cover 会裁切);其余优先用瘦封面(竖图,默认 cover 铺满),无瘦封面再退主封面 + contain;
/// 都缺失则渲染占位渐变。
class _MovieCover extends StatelessWidget {
  const _MovieCover({
    required this.movieNumber,
    required this.thinCoverImage,
    required this.coverImage,
  });

  final String movieNumber;
  final MovieImageDto? thinCoverImage;
  final MovieImageDto? coverImage;

  @override
  Widget build(BuildContext context) {
    final thinCoverUrl = _resolveMovieImageUrl(thinCoverImage);
    final coverUrl = _resolveMovieImageUrl(coverImage);

    // FC2- 番号统一用主封面 + contain 完整展示(其封面多为横图,cover 会裁切)。
    if (movieNumber.startsWith('FC2-') && coverUrl != null) {
      return MaskedImage(url: coverUrl, fit: BoxFit.contain);
    }

    if (thinCoverUrl != null) {
      return MaskedImage(url: thinCoverUrl);
    }

    if (coverUrl != null) {
      return MaskedImage(url: coverUrl, fit: BoxFit.contain);
    }

    // 纯图片卡缺图态统一为 muted 纯色块：不带渐变 / 居中图标。
    return ColoredBox(
      key: Key('movie-summary-card-placeholder-$movieNumber'),
      color: context.appColors.surfaceMuted,
    );
  }
}

String? _resolveMovieImageUrl(MovieImageDto? image) {
  final url = image?.origin.trim();
  if (url == null || url.isEmpty) {
    return null;
  }
  return url;
}
