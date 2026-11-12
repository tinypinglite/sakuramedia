import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/feedback/app_inline_spinner.dart';
import 'package:sakuramedia/widgets/base/interaction/app_interactive_surface.dart';
import 'package:sakuramedia/widgets/base/layout/surface/app_surface.dart';
import 'package:sakuramedia/features/movies/presentation/widgets/detail/movie_detail_inspector_panel.dart';
import 'package:sakuramedia/l10n/app_localizations.dart';

/// 影片详情照片下方的标题操作信息块：标题全宽在上，
/// 下方宽屏左右双列（左操作列 = 分体播放键 + 六键一行 / 右信息）、窄屏上下堆叠。
/// 坐在浅色模糊背景上，文字走深色系（与压图的白色系区分）。
class MovieDetailInfoBlock extends StatelessWidget {
  const MovieDetailInfoBlock({
    super.key,
    required this.isSubscribed,
    this.overlayTitle,
    this.eyebrow,
    this.metaItems = const <MovieDetailMetaItem>[],
    this.fileSizeLabel,
    this.watchLabel,
    this.watchTooltip,
    this.onPlayTap,
    this.isPlayLoading = false,
    this.onSubscriptionTap,
    this.isSubscriptionUpdating = false,
    this.isFavorite = false,
    this.onFavoriteTap,
    this.isFavoriteUpdating = false,
    this.onPlaylistTap,
    this.playlistTooltip,
    this.onMoreActionsTap,
    this.isMoreActionsUpdating = false,
    this.mergePlaybackLabel,
    this.onMergePlaybackTap,
    this.isMergePlaybackLoading = false,
    this.onInspectorPaneTap,
    this.showReviewAction = true,
    this.ratingPanel,
  });

  final bool isSubscribed;

  /// 全宽主标题（不含番号，番号由 [eyebrow] 承载）；为 null/空时不显示。
  final String? overlayTitle;

  /// 标题上方的小标签（通常是番号）；为 null/空时不显示。
  final String? eyebrow;

  /// 标题下的元信息段（评分｜评论｜想看｜看过｜热度｜上映日期｜时长｜厂商｜导演），
  /// 为空时整行不显示。
  final List<MovieDetailMetaItem> metaItems;

  /// 选中媒体的文件大小（如 20.99 GB），为 null/空时不显示。
  final String? fileSizeLabel;

  final String? watchLabel;
  final String? watchTooltip;

  final VoidCallback? onPlayTap;

  /// 播放动作进行中（如合并播放探测/拉起外部播放器），按钮显示 loading 并禁用。
  final bool isPlayLoading;

  final VoidCallback? onSubscriptionTap;
  final bool isSubscriptionUpdating;
  final bool isFavorite;
  final VoidCallback? onFavoriteTap;
  final bool isFavoriteUpdating;
  final VoidCallback? onPlaylistTap;

  /// 播放列表键的无障碍提示（加入/管理）；为 null 时用当前语言的“播放列表”。
  final String? playlistTooltip;
  final Future<void> Function(Offset globalPosition)? onMoreActionsTap;
  final bool isMoreActionsUpdating;

  /// 合并播放次入口（多段媒体才有），为 null/空时不显示。
  final String? mergePlaybackLabel;
  final VoidCallback? onMergePlaybackTap;
  final bool isMergePlaybackLoading;

  /// 评论 / 缩略图入口：打开对应功能弹窗；null 时两个键不渲染。
  final ValueChanged<MovieDetailInspectorPane>? onInspectorPaneTap;

  /// 评论入口是否可见；缩略图入口不受影响。
  final bool showReviewAction;

  /// 展开在元信息行下方的内联评分面板；null 时不渲染。
  final Widget? ratingPanel;

  /// 宽窄屏分界：以下走上下堆叠，以上走左右双列。
  static const double wideBreakpoint = 600;

  /// 左操作列固定宽：六个键一行，每键 6×46 + 5×4 = 296（原三键时为 200/键 64）。
  static const double actionsColumnWidth = 296;

  /// 操作列是否值得出现：播放/合并之外的六键（订阅/列表/评论/收藏/缩略图/更多）
  /// 只要回调在就保留，不可播时也不整体消失。判定放在 [_InfoActionsColumn.isVisible]，
  /// 父级与自身共用。

  @override
  Widget build(BuildContext context) {
    final spacing = context.appSpacing;
    final info = _heroInfo;
    final hasInfo = !info.isEmpty;
    final playlistTooltip =
        this.playlistTooltip ??
        AppLocalizations.of(context).movieWidgetPlaylistTooltip;
    return LayoutBuilder(
      builder: (context, constraints) {
        // 宽窄判定用**实际可用宽度**：桌面壳层侧栏会吃掉窗口宽度，只看
        // MediaQuery 的窗口宽会在窄窗口下把信息列挤到不可读。
        final availableWidth = constraints.maxWidth;
        final isWide =
            !availableWidth.isFinite || availableWidth >= wideBreakpoint;
        final actions = _InfoActionsColumn(
          onPlayTap: onPlayTap,
          isPlayLoading: isPlayLoading,
          isSubscribed: isSubscribed,
          onSubscriptionTap: onSubscriptionTap,
          isSubscriptionUpdating: isSubscriptionUpdating,
          isFavorite: isFavorite,
          onFavoriteTap: onFavoriteTap,
          isFavoriteUpdating: isFavoriteUpdating,
          onPlaylistTap: onPlaylistTap,
          playlistTooltip: playlistTooltip,
          onMoreActionsTap: onMoreActionsTap,
          isMoreActionsUpdating: isMoreActionsUpdating,
          mergePlaybackLabel: mergePlaybackLabel,
          onMergePlaybackTap: onMergePlaybackTap,
          isMergePlaybackLoading: isMergePlaybackLoading,
          onInspectorPaneTap: onInspectorPaneTap,
          showReviewAction: showReviewAction,
        );
        final hasActions = actions.isVisible;
        final title = overlayTitle?.trim() ?? '';
        final eyebrow = this.eyebrow?.trim() ?? '';
        if (title.isEmpty && eyebrow.isEmpty && !hasInfo && !hasActions) {
          return const SizedBox.shrink();
        }
        final content = Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (eyebrow.isNotEmpty) ...[
              _InfoEyebrow(label: eyebrow),
              if (title.isNotEmpty) SizedBox(height: spacing.xs),
            ],
            if (title.isNotEmpty)
              Text(
                title,
                key: const Key('movie-detail-hero-overlay-title'),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: resolveAppTextStyle(
                  context,
                  size: AppTextSize.s18,
                  weight: AppTextWeight.semibold,
                  tone: AppTextTone.primary,
                ),
              ),
            if (hasInfo || hasActions) ...[
              SizedBox(height: isWide ? spacing.md : spacing.xs),
              if (isWide)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    if (hasActions) ...[
                      SizedBox(width: actionsColumnWidth, child: actions),
                      if (hasInfo) SizedBox(width: spacing.md),
                    ],
                    if (hasInfo)
                      Expanded(
                        child: _InfoColumn(
                          info: info,
                          ratingPanel: ratingPanel,
                        ),
                      ),
                  ],
                )
              else
                Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _InfoColumn(info: info, ratingPanel: ratingPanel),
                    if (hasInfo) SizedBox(height: spacing.sm),
                    if (hasActions) actions,
                  ],
                ),
            ],
          ],
        );
        return Padding(
          padding: EdgeInsets.fromLTRB(spacing.md, spacing.sm, spacing.md, 0),
          child: content,
        );
      },
    );
  }

  _HeroInfo get _heroInfo => _HeroInfo(
    metaItems: metaItems,
    fileSizeLabel: fileSizeLabel?.trim().isNotEmpty == true
        ? fileSizeLabel!.trim()
        : null,
    watchLabel: watchLabel,
    watchTooltip: watchTooltip ?? watchLabel,
  );
}

/// 元信息段：有合适图标的用图标 + 数值（如评分/热度），没有的用文字
///（如 `厂商 · DAHLIA`）。
class MovieDetailMetaItem {
  const MovieDetailMetaItem({
    this.key,
    this.icon,
    this.iconColor,
    required this.text,
  });

  final Key? key;
  final IconData? icon;
  final Color? iconColor;
  final String text;
}

/// 标题上方的番号文字：内容层信息，不做玻璃材质。
class _InfoEyebrow extends StatelessWidget {
  const _InfoEyebrow({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      key: const Key('movie-detail-hero-overlay-eyebrow'),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: resolveAppTextStyle(
        context,
        size: AppTextSize.s12,
        weight: AppTextWeight.medium,
        tone: AppTextTone.secondary,
      ),
    );
  }
}

/// 右信息列的数据快照，避免 Column/Row 两处重复判空。
class _HeroInfo {
  const _HeroInfo({
    this.metaItems = const <MovieDetailMetaItem>[],
    this.fileSizeLabel,
    this.watchLabel,
    this.watchTooltip,
  });

  final List<MovieDetailMetaItem> metaItems;
  final String? fileSizeLabel;
  final String? watchLabel;
  final String? watchTooltip;

  bool get isEmpty =>
      metaItems.isEmpty && fileSizeLabel == null && watchLabel == null;
}

/// 元信息段：图标（有的话）+ 数值/文字，单行内不换行。
class _MetaSegment extends StatelessWidget {
  const _MetaSegment({required this.item});

  final MovieDetailMetaItem item;

  @override
  Widget build(BuildContext context) {
    final content = _buildContent(context);
    return KeyedSubtree(key: item.key, child: content);
  }

  Widget _buildContent(BuildContext context) {
    final icon = item.icon;
    if (icon == null) {
      return Text(
        item.text,
        style: resolveAppTextStyle(
          context,
          size: AppTextSize.s12,
          weight: AppTextWeight.regular,
          tone: AppTextTone.secondary,
        ),
      );
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          size: context.appComponentTokens.iconSizeXs,
          color: item.iconColor ?? context.appTextPalette.secondary,
        ),
        SizedBox(width: context.appSpacing.xs),
        Text(
          item.text,
          style: resolveAppTextStyle(
            context,
            size: AppTextSize.s12,
            weight: AppTextWeight.regular,
            tone: AppTextTone.secondary,
          ),
        ),
      ],
    );
  }
}

/// 右信息列：深色字（坐浅底）。
class _InfoColumn extends StatelessWidget {
  const _InfoColumn({required this.info, this.ratingPanel});

  final _HeroInfo info;
  final Widget? ratingPanel;

  @override
  Widget build(BuildContext context) {
    final spacing = context.appSpacing;
    if (info.isEmpty) return const SizedBox.shrink();
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (info.metaItems.isNotEmpty)
          Wrap(
            key: const Key('movie-detail-hero-overlay-meta'),
            spacing: context.appSpacing.sm,
            runSpacing: context.appSpacing.xs,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              for (var index = 0; index < info.metaItems.length; index++) ...[
                if (index > 0)
                  Text(
                    '·',
                    style: resolveAppTextStyle(
                      context,
                      size: AppTextSize.s12,
                      weight: AppTextWeight.regular,
                      tone: AppTextTone.muted,
                    ),
                  ),
                _MetaSegment(item: info.metaItems[index]),
              ],
            ],
          ),
        if (ratingPanel != null) ...[
          SizedBox(height: spacing.sm),
          ratingPanel!,
        ],
        if (info.fileSizeLabel != null) ...[
          SizedBox(height: spacing.xs),
          Text(
            info.fileSizeLabel!,
            key: const Key('movie-detail-hero-overlay-size'),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: resolveAppTextStyle(
              context,
              size: AppTextSize.s12,
              weight: AppTextWeight.regular,
              tone: AppTextTone.secondary,
            ),
          ),
        ],
        if (info.watchLabel != null) ...[
          SizedBox(height: spacing.xs),
          Align(
            alignment: Alignment.centerLeft,
            child: Tooltip(
              message: info.watchTooltip ?? info.watchLabel!,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.history_rounded,
                    size: context.appComponentTokens.iconSizeXs,
                    color: context.appTextPalette.secondary,
                  ),
                  SizedBox(width: spacing.xs),
                  Flexible(
                    child: Text(
                      info.watchLabel!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: resolveAppTextStyle(
                        context,
                        size: AppTextSize.s12,
                        tone: AppTextTone.secondary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// 左操作列：白色分体播放键（左播放 / 右合并，五五开）+ 订阅/播放列表/评论/收藏/缩略图/更多六键。
class _InfoActionsColumn extends StatelessWidget {
  const _InfoActionsColumn({
    required this.onPlayTap,
    required this.isPlayLoading,
    required this.isSubscribed,
    required this.onSubscriptionTap,
    required this.isSubscriptionUpdating,
    required this.isFavorite,
    required this.onFavoriteTap,
    required this.isFavoriteUpdating,
    required this.onPlaylistTap,
    required this.playlistTooltip,
    required this.onMoreActionsTap,
    required this.isMoreActionsUpdating,
    required this.mergePlaybackLabel,
    required this.onMergePlaybackTap,
    required this.isMergePlaybackLoading,
    required this.onInspectorPaneTap,
    required this.showReviewAction,
  });

  final VoidCallback? onPlayTap;
  final bool isPlayLoading;
  final bool isSubscribed;
  final VoidCallback? onSubscriptionTap;
  final bool isSubscriptionUpdating;
  final bool isFavorite;
  final VoidCallback? onFavoriteTap;
  final bool isFavoriteUpdating;
  final VoidCallback? onPlaylistTap;
  final String playlistTooltip;
  final Future<void> Function(Offset globalPosition)? onMoreActionsTap;
  final bool isMoreActionsUpdating;
  final String? mergePlaybackLabel;
  final VoidCallback? onMergePlaybackTap;
  final bool isMergePlaybackLoading;
  final ValueChanged<MovieDetailInspectorPane>? onInspectorPaneTap;
  final bool showReviewAction;

  bool get _hasMerge => mergePlaybackLabel?.trim().isNotEmpty == true;

  /// 是否有任何可渲染的操作键；父级用它决定是否给操作列留位。
  bool get isVisible =>
      onPlayTap != null ||
      isPlayLoading ||
      _hasMerge ||
      onSubscriptionTap != null ||
      isSubscriptionUpdating ||
      onFavoriteTap != null ||
      isFavoriteUpdating ||
      onPlaylistTap != null ||
      onMoreActionsTap != null ||
      isMoreActionsUpdating ||
      onInspectorPaneTap != null;

  @override
  Widget build(BuildContext context) {
    final spacing = context.appSpacing;
    final tokens = context.appComponentTokens;
    final inspectorPaneTap = onInspectorPaneTap;
    final l10n = AppLocalizations.of(context);
    final keys = <Widget>[
      _InfoActionKey(
        key: const Key('movie-detail-hero-subscription-icon'),
        tooltip: isSubscribed
            ? l10n.movieWidgetSubscribed
            : l10n.movieWidgetSubscribe,
        onTap: isSubscriptionUpdating ? null : onSubscriptionTap,
        child: isSubscriptionUpdating
            ? AppInlineSpinner(
                key: const Key('movie-detail-hero-subscription-loading'),
                color: context.appTextPalette.secondary,
              )
            : Icon(
                isSubscribed
                    ? Icons.favorite_rounded
                    : Icons.favorite_border_rounded,
                size: tokens.iconSizeSm,
                color: isSubscribed
                    ? context.appColors.subscriptionHeartIcon
                    : context.appTextPalette.secondary,
              ),
      ),
      _InfoActionKey(
        key: const Key('movie-detail-playlist-trigger'),
        tooltip: playlistTooltip,
        onTap: onPlaylistTap,
        child: Icon(
          Icons.playlist_add_rounded,
          size: tokens.iconSizeSm,
          color: context.appTextPalette.secondary,
        ),
      ),
      // 收藏快捷键替换原磁力搜索位；磁力搜索已收进「更多」。
      _InfoActionKey(
        key: const Key('movie-detail-hero-favorite-icon'),
        tooltip: isFavorite
            ? l10n.movieWidgetRemoveFavorite
            : l10n.movieWidgetFavoriteMovie,
        onTap: isFavoriteUpdating ? null : onFavoriteTap,
        child: isFavoriteUpdating
            ? AppInlineSpinner(
                key: const Key('movie-detail-hero-favorite-loading'),
                color: context.appTextPalette.secondary,
              )
            : Icon(
                isFavorite ? Icons.star_rounded : Icons.star_border_rounded,
                size: tokens.iconSizeSm,
                color: isFavorite
                    ? context.appColors.subscriptionHeartIcon
                    : context.appTextPalette.secondary,
              ),
      ),
      // 内容入口：评论 / 缩略图，与左侧动作键同排同形，
      // 只靠 tooltip 区分；不藏进区块标题或媒体行图标。
      if (inspectorPaneTap != null) ...<Widget>[
        if (showReviewAction)
          _InfoActionKey(
            key: const Key('movie-detail-hero-review-icon'),
            tooltip: l10n.movieWidgetReview,
            onTap: () => inspectorPaneTap(MovieDetailInspectorPane.review),
            child: Icon(
              Icons.chat_bubble_outline_rounded,
              size: tokens.iconSizeSm,
              color: context.appTextPalette.secondary,
            ),
          ),
        _InfoActionKey(
          key: const Key('movie-detail-hero-thumbnail-icon'),
          tooltip: l10n.movieWidgetThumbnail,
          onTap: () => inspectorPaneTap(MovieDetailInspectorPane.thumbnail),
          child: Icon(
            Icons.photo_library_outlined,
            size: tokens.iconSizeSm,
            color: context.appTextPalette.secondary,
          ),
        ),
      ],
      _InfoMoreKey(isUpdating: isMoreActionsUpdating, onTap: onMoreActionsTap),
    ];
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (onPlayTap != null || isPlayLoading || _hasMerge)
          _InfoSplitPlayButton(
            onPlayTap: isPlayLoading ? null : onPlayTap,
            isPlayLoading: isPlayLoading,
            hasMerge: _hasMerge,
            mergeTooltip: _hasMerge ? mergePlaybackLabel!.trim() : '',
            onMergeTap: isMergePlaybackLoading ? null : onMergePlaybackTap,
            isMergeLoading: isMergePlaybackLoading,
          ),
        SizedBox(height: spacing.xs),
        AppSurface(
          borderRadius: context.appRadius.mdBorder,
          role: AppSurfaceRole.control,
          child: Row(
            children: <Widget>[
              for (var index = 0; index < keys.length; index++) ...<Widget>[
                if (index > 0)
                  SizedBox(
                    width: 1,
                    height: tokens.iconSizeSm,
                    child: ColoredBox(color: context.appColors.divider),
                  ),
                Expanded(child: keys[index]),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// 播放键：品牌色填充的播放主键 + 次级描边合并键（有合并时约 2:1）。
class _InfoSplitPlayButton extends StatelessWidget {
  const _InfoSplitPlayButton({
    required this.onPlayTap,
    required this.isPlayLoading,
    required this.hasMerge,
    required this.mergeTooltip,
    required this.onMergeTap,
    required this.isMergeLoading,
  });

  final VoidCallback? onPlayTap;
  final bool isPlayLoading;
  final bool hasMerge;
  final String mergeTooltip;
  final VoidCallback? onMergeTap;
  final bool isMergeLoading;

  @override
  Widget build(BuildContext context) {
    final tokens = context.appComponentTokens;
    final primary = Theme.of(context).colorScheme.primary;
    final onPrimary = Theme.of(context).colorScheme.onPrimary;
    final playEnabled = onPlayTap != null || isPlayLoading;
    final playForeground = playEnabled
        ? onPrimary
        : context.appTextPalette.secondary;
    final playBackground = playEnabled
        ? primary
        : context.appColors.surfaceMuted;

    return Row(
      children: [
        Expanded(
          flex: hasMerge ? 2 : 1,
          child: Container(
            height: tokens.buttonHeightMd,
            decoration: BoxDecoration(
              color: playBackground,
              borderRadius: context.appRadius.pillBorder,
            ),
            child: AppInteractiveSurface(
              enabled: onPlayTap != null,
              key: const Key('movie-detail-hero-play-button'),
              onTap: onPlayTap,
              child: Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (isPlayLoading)
                      AppInlineSpinner(color: playForeground)
                    else ...[
                      Icon(
                        Icons.play_arrow_rounded,
                        size: tokens.iconSizeSm,
                        color: playForeground,
                      ),
                      SizedBox(width: tokens.buttonGapMd),
                      Text(
                        AppLocalizations.of(context).movieWidgetPlay,
                        style: resolveAppTextStyle(
                          context,
                          size: AppTextSize.s14,
                          weight: AppTextWeight.medium,
                          tone: AppTextTone.primary,
                        ).copyWith(color: playForeground),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
        if (hasMerge) ...[
          SizedBox(width: tokens.buttonGapXs),
          Expanded(
            child: Container(
              height: tokens.buttonHeightMd,
              decoration: BoxDecoration(
                color: Colors.transparent,
                borderRadius: context.appRadius.pillBorder,
                border: Border.all(color: primary.withValues(alpha: 0.45)),
              ),
              child: Tooltip(
                message: mergeTooltip,
                child: AppInteractiveSurface(
                  enabled: onMergeTap != null,
                  key: const Key('movie-detail-merge-playback-button'),
                  onTap: onMergeTap,
                  child: Center(
                    child: isMergeLoading
                        ? AppInlineSpinner(color: primary)
                        : Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.merge_rounded,
                                size: tokens.iconSizeSm,
                                color: primary,
                              ),
                              SizedBox(width: tokens.buttonGapMd),
                              Text(
                                AppLocalizations.of(context).movieWidgetMerge,
                                style: resolveAppTextStyle(
                                  context,
                                  size: AppTextSize.s14,
                                  weight: AppTextWeight.medium,
                                  tone: AppTextTone.primary,
                                ).copyWith(color: primary),
                              ),
                            ],
                          ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// 中性小操作键（订阅 / 播放列表 / 评论 / 收藏 / 缩略图）。
///
/// 底色与描边由外层 [AppSurface] 动作组统一承载，这里只负责图标和点击。
class _InfoActionKey extends StatelessWidget {
  const _InfoActionKey({
    super.key,
    required this.tooltip,
    required this.onTap,
    required this.child,
  });

  final String tooltip;
  final VoidCallback? onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: AppInteractiveSurface(
        enabled: onTap != null,
        onTap: onTap,
        semanticLabel: tooltip,
        child: SizedBox(
          height: context.appComponentTokens.buttonHeightMd,
          child: Center(child: child),
        ),
      ),
    );
  }
}

/// 更多操作键：需要点击位置弹菜单，用 onTapDown 接。
class _InfoMoreKey extends StatelessWidget {
  const _InfoMoreKey({required this.isUpdating, required this.onTap});

  final bool isUpdating;
  final Future<void> Function(Offset globalPosition)? onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = context.appComponentTokens;
    final button = SizedBox(
      key: const Key('movie-detail-hero-more-actions-button'),
      height: tokens.buttonHeightMd,
      child: Center(
        child: isUpdating
            ? AppInlineSpinner(
                key: const Key('movie-detail-hero-more-actions-loading'),
                color: context.appTextPalette.secondary,
              )
            : Icon(
                Icons.more_horiz_rounded,
                size: tokens.iconSizeSm,
                color: context.appTextPalette.secondary,
              ),
      ),
    );

    if (onTap == null || isUpdating) {
      return Tooltip(
        message: AppLocalizations.of(context).movieWidgetMoreActions,
        child: button,
      );
    }

    return Tooltip(
      message: AppLocalizations.of(context).movieWidgetMoreActions,
      child: AppInteractiveSurface(
        onTap: () {},
        onTapDown: (details) => onTap!(details.globalPosition),
        focusRingRadius: context.appRadius.smBorder,
        child: button,
      ),
    );
  }
}
