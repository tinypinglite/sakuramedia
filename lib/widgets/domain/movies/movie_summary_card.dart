import 'dart:async';
import 'dart:ui' as ui;

import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/core/platform/haptic_feedback.dart';
import 'package:sakuramedia/features/movies/data/dto/listing/movie_list_item_dto.dart';
import 'package:sakuramedia/features/movies/presentation/actions/movie_inspector_launcher.dart';
import 'package:sakuramedia/features/movies/presentation/actions/movie_playback_launcher.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/interaction/app_cover_hover_info.dart';
import 'package:sakuramedia/widgets/base/interaction/app_interactive_surface.dart';
import 'package:sakuramedia/widgets/base/interaction/selection/selection_check_badge.dart';
import 'package:sakuramedia/widgets/base/media/images/app_image_action_trigger.dart';
import 'package:sakuramedia/widgets/base/media/images/masked_image.dart';
import 'package:sakuramedia/widgets/domain/movies/subscription_heart_badge.dart';
import 'package:skeletonizer/skeletonizer.dart';

/// 影片摘要卡：封面即卡片，底部一条信息层。
///
/// 设计依据（Apple HIG）：
/// - Materials：收起态不铺底色，番号直接压在封面上；悬停展开时才渐显
///   「压暗 + 1px 顶部高光」的 material，把展开内容托起来；
/// - Motion：展开是高频交互，动效取 180ms ease-out——内容自下而上滑入淡入、
///   面板高度沿底边长大，不加入回弹；系统「减弱动态效果」时全部退化为瞬时切换；
/// - Layout（渐进披露）：默认态只给番号与状态角标，标题/时长/日期与播放/订阅
///   动作在指针悬停时展开，减少网格里的信息噪音；
/// - Typography：行高与 tracking 取 macOS 文本样式（13pt→16/−0.08、11pt→14/+0.06、
///   10pt→13/+0.12）。
///
/// 触摸端没有 hover，展开态不会被触发，卡片停留在默认态。
class MovieSummaryCard extends StatefulWidget {
  const MovieSummaryCard({
    super.key,
    required this.movie,
    this.showStatusBadges = true,
    this.rank,
    this.secondaryLabel,
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
  final bool showStatusBadges;
  final int? rank;
  final String? secondaryLabel;
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
  State<MovieSummaryCard> createState() => _MovieSummaryCardState();
}

class _MovieSummaryCardState extends State<MovieSummaryCard> {
  bool _hovered = false;
  bool _inspectorLoading = false;

  MovieListItemDto get movie => widget.movie;

  /// 悬停时封面推近的幅度。网格 gutter ≥ 16，1.03 不会压到相邻卡片。
  static const double _hoverCoverScale = 1.03;

  /// 展开/收起的过渡时长：短到不打断扫视，长得足以看清内容。
  static const Duration _hoverDuration = Duration(milliseconds: 180);

  /// 选择模式下不展开：那一层承载的播放/订阅/检查器在选中时都被屏蔽，
  /// 展开只会带来手势冲突与信息噪音。
  bool get _expanded => _hovered && !widget.selectionMode;

  void _setHovered(bool value) {
    if (_hovered == value) return;
    setState(() => _hovered = value);
  }

  /// 先取默认媒体让缩略图页签可用（取不到也能开），再按平台弹出弹窗。
  Future<void> _openInspector() async {
    if (_inspectorLoading) {
      return;
    }
    setState(() => _inspectorLoading = true);
    final media = await fetchDefaultInspectorMedia(
      context,
      movieNumber: movie.movieNumber,
    );
    if (!mounted) {
      return;
    }
    setState(() => _inspectorLoading = false);
    showMovieInspector(
      context,
      movieNumber: movie.movieNumber,
      selectedMedia: media,
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final componentTokens = context.appComponentTokens;
    final spacing = context.appSpacing;
    // 系统开启「减弱动态效果」时退化为瞬时切换（HIG: make motion optional）。
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final motion = reduceMotion ? Duration.zero : _hoverDuration;
    final selected = widget.selectionMode && widget.isSelected;
    final handlesSubscriptionTapAtCardLevel =
        !widget.selectionMode &&
        widget.onSubscriptionTap != null &&
        (widget.onTap != null || widget.onRequestMenu != null);
    final showCluster = widget.showStatusBadges && !widget.selectionMode;
    final showHeat = widget.showStatusBadges && movie.heat > 0;

    final card = AnimatedContainer(
      duration: motion,
      curve: Curves.easeOutCubic,
      key: Key('movie-summary-card-${movie.movieNumber}'),
      decoration: BoxDecoration(
        color: colors.surfaceMuted,
        borderRadius: context.appRadius.mdBorder,
        border: selected
            ? Border.all(color: colors.selectionBorder, width: 2)
            : null,
        boxShadow: _expanded
            ? [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.16),
                  blurRadius: 20,
                  offset: const Offset(0, 6),
                ),
              ]
            : null,
      ),
      clipBehavior: Clip.antiAlias,
      child: AspectRatio(
        aspectRatio: componentTokens.movieCardAspectRatio,
        // 骨架态整卡收敛成一块 shimmer 圆角块：热度 / 排名 / 订阅 / 信息按钮
        // 等细碎骨块不再单独透出。非骨架态下 [Skeleton.unite] 原样渲染。
        child: Skeleton.unite(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final wrapHeat =
                  showHeat && _shouldWrapHeat(context, constraints.maxWidth);
              return Stack(
                fit: StackFit.expand,
                children: [
                  AnimatedScale(
                    scale: _expanded ? _hoverCoverScale : 1,
                    duration: motion,
                    curve: Curves.easeOutCubic,
                    child: _MovieCover(
                      movieNumber: movie.movieNumber,
                      thinCoverImage: movie.thinCoverImage,
                      coverImage: movie.coverImage,
                    ),
                  ),
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: _buildInfoLayer(
                      context,
                      reduceMotion: reduceMotion,
                      duration: motion,
                    ),
                  ),
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
                              isUpdating: widget.isSubscriptionUpdating,
                              onTap: handlesSubscriptionTapAtCardLevel
                                  ? null
                                  : widget.onSubscriptionTap,
                            ),
                          ),
                          if (movie.canPlay)
                            _StatusBadge(
                              key: Key(
                                'movie-summary-card-status-playable-${movie.movieNumber}',
                              ),
                              icon: Icons.play_arrow_rounded,
                              iconColor: context.appTextPalette.onMedia,
                              background: colors.movieCardPlayableBadgeBackground,
                            ),
                          if (movie.maxMediaWidth >= 3840)
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
                  if (widget.selectionMode)
                    Positioned(
                      top: spacing.xs,
                      left: spacing.xs,
                      child: IgnorePointer(
                        child: SelectionCheckBadge(isSelected: widget.isSelected),
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );

    final Widget interactiveCard;
    if (widget.selectionMode) {
      interactiveCard = AppInteractiveSurface(
        key: Key('movie-summary-card-checkbox-${movie.movieNumber}'),
        enabled: widget.onSelectedChanged != null,
        onTap: () => widget.onSelectedChanged?.call(!widget.isSelected),
        child: card,
      );
    } else if (widget.onTap == null && widget.onRequestMenu == null) {
      interactiveCard = card;
    } else {
      interactiveCard = AppImageActionTrigger(
        onTap: handlesSubscriptionTapAtCardLevel ? null : widget.onTap,
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
                  if (!widget.isSubscriptionUpdating) {
                    triggerSelectionHaptic();
                    widget.onSubscriptionTap!();
                  }
                } else {
                  widget.onTap?.call();
                }
              }
            : null,
        onRequestMenu: widget.onRequestMenu,
        child: card,
      );
    }

    return MouseRegion(
      onEnter: (_) => _setHovered(true),
      onExit: (_) => _setHovered(false),
      child: interactiveCard,
    );
  }

  /// 信息层：正常态用 AnimatedSize + AnimatedSwitcher 让面板沿底边长大、内容
  /// 自下而上滑入淡入；「减弱动态效果」时直接换内容——AnimatedSize 在零时长下
  /// 会在 layout 阶段改写自身状态，必须绕开。
  Widget _buildInfoLayer(
    BuildContext context, {
    required bool reduceMotion,
    required Duration duration,
  }) {
    final content = _expanded
        ? _buildExpandedInfo(context)
        : _buildCollapsedInfo(context);
    final panel = _InfoPanel(
      expanded: _expanded,
      duration: duration,
      child: reduceMotion
          ? content
          : AnimatedSwitcher(
              duration: duration,
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeIn,
              transitionBuilder: (child, animation) => FadeTransition(
                opacity: animation,
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0, 0.12),
                    end: Offset.zero,
                  ).animate(animation),
                  child: child,
                ),
              ),
              layoutBuilder: (currentChild, previousChildren) => Stack(
                alignment: Alignment.bottomLeft,
                children: <Widget>[...previousChildren, ?currentChild],
              ),
              child: KeyedSubtree(
                key: ValueKey<bool>(_expanded),
                child: content,
              ),
            ),
    );
    if (reduceMotion) {
      return panel;
    }
    return AnimatedSize(
      duration: duration,
      curve: Curves.easeOutCubic,
      alignment: Alignment.bottomCenter,
      child: panel,
    );
  }

  /// 顶部一行放不下左上角角标与右上角热度时，热度折到下一行。
  bool _shouldWrapHeat(BuildContext context, double cardWidth) {
    final spacing = context.appSpacing;
    final tokens = context.appComponentTokens;
    final heatText = TextPainter(
      text: TextSpan(
        text: _formatMovieHeat(movie.heat),
        style: _onMediaStyle(context, size: AppTextSize.s10),
      ),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
    )..layout();
    final heatWidth =
        spacing.sm * 2 + tokens.iconSizeXs + spacing.xs + heatText.width + 2;
    heatText.dispose();
    final statusWidth =
        tokens.movieCardStatusBadgeSize +
        (!widget.selectionMode && movie.canPlay
            ? spacing.xs + tokens.movieCardStatusBadgeSize
            : 0) +
        (!widget.selectionMode && movie.maxMediaWidth >= 3840
            ? spacing.xs + spacing.sm + tokens.movieCardStatusBadgeSize
            : 0);
    return statusWidth + heatWidth + spacing.xs * 3 > cardWidth;
  }

  /// 默认态：番号（+ 推荐理由）与右下角排名。触摸端也只有这一层。
  Widget _buildCollapsedInfo(BuildContext context) {
    final spacing = context.appSpacing;
    final number = Text(
      movie.movieNumber,
      key: Key('movie-summary-card-number-${movie.movieNumber}'),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: _onMediaStyle(
        context,
        weight: AppTextWeight.semibold,
        size: AppTextSize.s12,
      ),
    );
    final Widget info;
    // 推荐理由（如「热门：某某女优」）在触摸端没有悬停可触发，常显为第二行，
    // 否则移动端会彻底看不到它。
    if (widget.secondaryLabel case final label?) {
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
            style: _onMediaStyle(
              context,
              size: AppTextSize.s10,
            ).copyWith(
              color: context.appTextPalette.onMedia.withValues(alpha: 0.72),
            ),
          ),
        ],
      );
    } else {
      info = number;
    }
    return Row(
      children: [
        Expanded(child: info),
        if (widget.rank != null) ...[
          SizedBox(width: spacing.sm),
          _RankBadge(rank: widget.rank!, movieNumber: movie.movieNumber),
        ],
        if (!widget.selectionMode) ...[
          SizedBox(width: spacing.xs),
          _CardInfoButton(
            movieNumber: movie.movieNumber,
            isLoading: _inspectorLoading,
            onTap: () => unawaited(_openInspector()),
          ),
        ],
      ],
    );
  }

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

  /// 悬停态：补上标题、时长/日期与播放/订阅/菜单动作，右下角留排名。
  Widget _buildExpandedInfo(BuildContext context) {
    final spacing = context.appSpacing;
    final showBadges = widget.showStatusBadges && !widget.selectionMode;
    // 动作按钮走全站共用的 [AppCoverHoverActionBar]（Wrap）：窄卡（相似影片条
    // 仅 165 逻辑宽）放不下时换行，避免整行溢出。排名徽标与信息按钮固定在行尾。
    final actions = <Widget>[
      // 播放是这一层的主操作，用白底实心；选择模式与不可播放时不出。
      if (showBadges && movie.canPlay)
        AppCoverHoverActionButton(
          key: Key('movie-summary-card-play-${movie.movieNumber}'),
          icon: Icons.play_arrow_rounded,
          primary: true,
          tooltip: '播放',
          onTap: () => _handlePlay(context),
        ),
      if (widget.onSubscriptionTap != null)
        AppCoverHoverActionButton(
          key: Key(
            'movie-summary-card-subscription-action-${movie.movieNumber}',
          ),
          icon: movie.isSubscribed
              ? Icons.favorite_rounded
              : Icons.favorite_border_rounded,
          tooltip: movie.isSubscribed ? '取消订阅' : '订阅影片',
          onTap: widget.isSubscriptionUpdating
              ? null
              : widget.onSubscriptionTap,
        ),
      if (widget.onToggleCollectionType != null)
        AppCoverHoverActionButton(
          key: Key('movie-summary-card-collection-type-${movie.movieNumber}'),
          icon: Icons.category_outlined,
          tooltip: '标记为合集/单体',
          onTap: widget.onToggleCollectionType,
        ),
      // 已订阅影片不可屏蔽，与右键菜单的显隐规则一致。
      if (widget.onBlacklist != null && !movie.isSubscribed)
        AppCoverHoverActionButton(
          key: Key('movie-summary-card-blacklist-${movie.movieNumber}'),
          icon: Icons.block_rounded,
          tooltip: '屏蔽影片',
          onTap: widget.onBlacklist,
        ),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          movie.movieNumber,
          key: Key('movie-summary-card-number-${movie.movieNumber}'),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: _onMediaStyle(
            context,
            weight: AppTextWeight.semibold,
            size: AppTextSize.s12,
          ),
        ),
        if (widget.secondaryLabel case final label?) ...[
          SizedBox(height: spacing.xs / 2),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: _onMediaStyle(
              context,
              size: AppTextSize.s10,
            ).copyWith(
              color: context.appTextPalette.onMedia.withValues(alpha: 0.72),
            ),
          ),
        ],
        SizedBox(height: spacing.xs / 2),
        Text(
          movie.title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: _onMediaStyle(
            context,
            size: AppTextSize.s12,
          ).copyWith(color: context.appTextPalette.onMedia.withValues(alpha: 0.78)),
        ),
        SizedBox(height: spacing.xs),
        Text(
          _metaLine(movie),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: _onMediaStyle(
            context,
            size: AppTextSize.s10,
          ).copyWith(color: context.appTextPalette.onMedia.withValues(alpha: 0.64)),
        ),
        SizedBox(height: spacing.sm),
        // 动作独占一行：4 个动作 + 排名 + 信息按钮挤在一行会在标准卡宽
        // （movieCardTargetWidth 220）折行，排名与信息按钮独立成行后动作始终单行。
        AppCoverHoverActionBar(actions: actions),
        if (actions.isNotEmpty) SizedBox(height: spacing.xs),
        Row(
          children: [
            const Spacer(),
            if (widget.rank != null) ...[
              _RankBadge(rank: widget.rank!, movieNumber: movie.movieNumber),
              SizedBox(width: spacing.xs),
            ],
            _CardInfoButton(
              movieNumber: movie.movieNumber,
              isLoading: _inspectorLoading,
              onTap: () => unawaited(_openInspector()),
            ),
          ],
        ),
      ],
    );
  }
}

/// 覆盖在封面上的信息面板：收起态完全透明，展开时渐显「压暗渐变 + 1px 顶部高光」。
///
/// 不用 [BackdropFilter]：卡片本身带 `clipBehavior` 与阴影（saveLayer），
/// 实测模糊会溢出面板范围把整张封面洗白；网格里几十张卡常驻模糊也会拖慢滚动。
/// 压暗渐变在浅色与深色封面上都能保证白字可读。
class _InfoPanel extends StatelessWidget {
  const _InfoPanel({
    required this.expanded,
    required this.duration,
    required this.child,
  });

  final bool expanded;
  final Duration duration;
  final Widget child;

  /// 展开态的压暗范围与顶部高光透明度。
  static const double _dimTopAlpha = 0.44;
  static const double _dimBottomAlpha = 0.72;
  static const double _hairlineAlpha = 0.12;

  @override
  Widget build(BuildContext context) {
    final spacing = context.appSpacing;
    const dim = Colors.black;
    // 收起态保留同一套渐变/描边结构、alpha 归零，AnimatedContainer 才能平滑插值。
    final decoration = BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          dim.withValues(alpha: expanded ? _dimTopAlpha : 0),
          dim.withValues(alpha: expanded ? _dimBottomAlpha : 0),
        ],
      ),
      border: Border(
        top: BorderSide(
          color: Colors.white.withValues(alpha: expanded ? _hairlineAlpha : 0),
          width: 1,
        ),
      ),
    );
    return AnimatedContainer(
      duration: duration,
      curve: Curves.easeOutCubic,
      decoration: decoration,
      padding: EdgeInsets.fromLTRB(
        spacing.md,
        spacing.sm,
        spacing.md,
        spacing.sm + spacing.xs / 2,
      ),
      child: child,
    );
  }
}

/// 卡片信息行右端的详情检查器入口：常显，点击打开评论 / 磁力 / 缩略图弹窗。
class _CardInfoButton extends StatelessWidget {
  const _CardInfoButton({
    required this.movieNumber,
    required this.isLoading,
    required this.onTap,
  });

  final String movieNumber;
  final bool isLoading;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final tokens = context.appComponentTokens;
    final size = tokens.movieCardStatusBadgeSize;
    return GestureDetector(
      key: Key('movie-summary-card-inspector-$movieNumber'),
      behavior: HitTestBehavior.opaque,
      onTap: isLoading ? null : onTap,
      child: MouseRegion(
        cursor: isLoading ? SystemMouseCursors.basic : SystemMouseCursors.click,
        child: Container(
          width: size,
          height: size,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: colors.mediaOverlayStrong,
            borderRadius: context.appRadius.pillBorder,
            border: Border.all(
              color: colors.borderSubtle.withValues(alpha: 0.42),
            ),
          ),
          child: isLoading
              ? SizedBox(
                  width: tokens.iconSize3xs,
                  height: tokens.iconSize3xs,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: context.appTextPalette.onMedia,
                  ),
                )
              : Icon(
                  Icons.info_outline_rounded,
                  size: tokens.iconSizeXs,
                  color: context.appTextPalette.onMedia,
                ),
        ),
      ),
    );
  }
}

/// 清晰度胶囊：毛玻璃底 + 4K/8K 粗体字，与订阅心、播放标同排。
class _ResolutionBadge extends StatelessWidget {
  const _ResolutionBadge({required this.movie, required this.movieNumber});

  final MovieListItemDto movie;
  final String movieNumber;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final componentTokens = context.appComponentTokens;
    final spacing = context.appSpacing;
    return IgnorePointer(
      child: ClipRRect(
        borderRadius: context.appRadius.pillBorder,
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: spacing.xs, sigmaY: spacing.xs),
          child: Container(
            key: Key('movie-summary-card-resolution-$movieNumber'),
            width: componentTokens.movieCardStatusBadgeSize + spacing.sm,
            height: componentTokens.movieCardStatusBadgeSize,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: colors.mediaOverlayStrong,
              borderRadius: context.appRadius.pillBorder,
              border: Border.all(
                color: colors.borderSubtle.withValues(alpha: 0.42),
              ),
            ),
            child: Text(
              movie.maxMediaWidth >= 7680 ? '8K' : '4K',
              style:
                  resolveAppTextStyle(
                    context,
                    size: AppTextSize.s12,
                    weight: AppTextWeight.semibold,
                    tone: AppTextTone.onMedia,
                  ).copyWith(
                    color: context.appTextPalette.onMedia,
                    fontWeight: FontWeight.w800,
                    height: 1,
                    leadingDistribution: TextLeadingDistribution.even,
                  ),
            ),
          ),
        ),
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
    final colors = context.appColors;
    final spacing = context.appSpacing;
    return Container(
      key: Key('movie-summary-card-heat-$movieNumber'),
      padding: EdgeInsets.symmetric(
        horizontal: spacing.sm,
        vertical: spacing.xs,
      ),
      decoration: BoxDecoration(
        color: colors.mediaOverlayStrong,
        borderRadius: context.appRadius.pillBorder,
        border: Border.all(color: colors.borderSubtle.withValues(alpha: 0.42)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.local_fire_department_rounded,
            size: context.appComponentTokens.iconSizeXs,
            color: colors.movieDetailHeatIcon,
          ),
          SizedBox(width: spacing.xs),
          Text(
            _formatMovieHeat(heat),
            key: Key('movie-summary-card-heat-text-$movieNumber'),
            style: _onMediaStyle(context, size: AppTextSize.s10),
          ),
        ],
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

/// 封面 / 信息条上的文字：onMedia 白色 + macOS 文本样式的行高与字距。
TextStyle _onMediaStyle(
  BuildContext context, {
  required AppTextSize size,
  AppTextWeight weight = AppTextWeight.regular,
}) {
  return switch (size) {
    AppTextSize.s12 => resolveAppTextStyle(
      context,
      size: size,
      weight: weight,
      tone: AppTextTone.onMedia,
      height: 16 / 13,
      letterSpacing: -0.08,
    ),
    AppTextSize.s10 => resolveAppTextStyle(
      context,
      size: size,
      weight: weight,
      tone: AppTextTone.onMedia,
      height: 13 / 10,
      letterSpacing: 0.12,
    ),
    _ => resolveAppTextStyle(
      context,
      size: size,
      weight: weight,
      tone: AppTextTone.onMedia,
    ),
  };
}

String _metaLine(MovieListItemDto movie) {
  final date = movie.releaseDate;
  final datePart = date == null
      ? ''
      : '${date.year}.${date.month.toString().padLeft(2, '0')}.'
            '${date.day.toString().padLeft(2, '0')}';
  if (datePart.isEmpty) {
    return '${movie.durationMinutes} 分钟';
  }
  return '${movie.durationMinutes} 分钟 · $datePart';
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
    final colors = context.appColors;
    return Container(
      key: Key('movie-summary-card-rank-$movieNumber'),
      padding: EdgeInsets.symmetric(
        horizontal: context.appSpacing.sm,
        vertical: context.appSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: colors.mediaOverlayStrong,
        borderRadius: context.appRadius.pillBorder,
        border: Border.all(color: colors.borderSubtle.withValues(alpha: 0.42)),
      ),
      child: Text(
        '#$rank',
        style: resolveAppTextStyle(
          context,
          size: AppTextSize.s10,
          weight: AppTextWeight.regular,
          tone: AppTextTone.onMedia,
        ),
      ),
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
    final colors = context.appColors;
    final componentTokens = context.appComponentTokens;
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

    return DecoratedBox(
      key: Key('movie-summary-card-placeholder-$movieNumber'),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            colors.surfaceMuted,
            Theme.of(
              context,
            ).colorScheme.primaryContainer.withValues(alpha: 0.38),
          ],
        ),
      ),
      child: Center(
        child: Skeleton.ignore(
        child: Icon(
          Icons.movie_creation_outlined,
          size: componentTokens.iconSize3xl,
          color: context.appTextPalette.muted,
        ),
      ),
      ),
    );
  }
}

String? _resolveMovieImageUrl(MovieImageDto? image) {
  final url = image?.bestAvailableUrl.trim();
  if (url == null || url.isEmpty) {
    return null;
  }
  return url;
}
