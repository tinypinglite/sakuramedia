import 'package:flutter/material.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/media/masked_image.dart';

/// 合集「成员」（切片 / 视频）在详情页的共享展示组件：列表行 [CollectionMemberRow]、
/// 网格卡 [CollectionMemberCard] 与「···」菜单 [CollectionMemberMenu]。
///
/// 切片合集与视频合集详情页结构一致，仅在 DTO、封面比例、副信息、占位图标、
/// 菜单项与 key 前缀上有差异，由各详情页把差异以参数喂入，避免两份近乎相同的实现重复。
/// 与「合集封面卡」[CollectionCoverCard] 同属一套范式。

/// 合集成员的「更多」菜单：可选「打开来源」（切片 → 影片，视频 → 详情）+「移出合集」。
///
/// [onCover] 为 `true` 时用于网格封面右上角，沿用半透明黑底白字圆形徽标样式；
/// 为 `false` 时用于列表行，渲染为贴合卡片表面的普通图标按钮。
class CollectionMemberMenu extends StatelessWidget {
  const CollectionMemberMenu({
    super.key,
    required this.menuKey,
    required this.onRemove,
    this.onOpenSource,
    this.openSourceLabel,
    this.removeLabel = '移出合集',
    this.onCover = true,
  });

  final Key menuKey;
  final VoidCallback onRemove;

  /// 「打开来源」动作；为 `null`（或缺少 [openSourceLabel]）时该菜单项隐藏。
  final VoidCallback? onOpenSource;
  final String? openSourceLabel;
  final String removeLabel;
  final bool onCover;

  @override
  Widget build(BuildContext context) {
    final label = openSourceLabel;
    final openSource = onOpenSource;
    final menuButton = PopupMenuButton<_MemberMenuAction>(
      key: menuKey,
      tooltip: '更多',
      padding: EdgeInsets.zero,
      iconSize: 16,
      position: PopupMenuPosition.under,
      icon: Icon(
        Icons.more_horiz_rounded,
        color: onCover ? Colors.white : context.appTextPalette.secondary,
        size: 16,
      ),
      onSelected: (action) {
        switch (action) {
          case _MemberMenuAction.openSource:
            openSource?.call();
          case _MemberMenuAction.remove:
            onRemove();
        }
      },
      itemBuilder: (context) => <PopupMenuEntry<_MemberMenuAction>>[
        if (openSource != null && label != null)
          PopupMenuItem<_MemberMenuAction>(
            value: _MemberMenuAction.openSource,
            child: Text(label),
          ),
        PopupMenuItem<_MemberMenuAction>(
          value: _MemberMenuAction.remove,
          child: Text(
            removeLabel,
            style: TextStyle(color: context.appTextPalette.error),
          ),
        ),
      ],
    );

    // 封面上用半透明黑底圆形徽标，列表行内贴合卡片表面、无额外底色。
    return SizedBox(
      width: 26,
      height: 26,
      child: onCover
          ? Material(
              color: Colors.black.withValues(alpha: 0.45),
              shape: const CircleBorder(),
              clipBehavior: Clip.antiAlias,
              child: menuButton,
            )
          : menuButton,
    );
  }
}

enum _MemberMenuAction { openSource, remove }

/// 合集成员的列表行：封面贴满左侧 + 标题/副信息，悬停显现拖拽手柄与更多菜单。
/// 整行点击触发 [onTap]（通常为从该位置连播整个合集）。
class CollectionMemberRow extends StatelessWidget {
  const CollectionMemberRow({
    super.key,
    required this.index,
    required this.coverUrl,
    required this.coverWidth,
    required this.coverAspectRatio,
    required this.title,
    required this.isHovered,
    required this.onTap,
    required this.menuKey,
    required this.dragHandleKey,
    required this.onRemove,
    this.subtitle,
    this.onOpenSource,
    this.openSourceLabel,
    this.coverFit = BoxFit.cover,
    this.placeholderIcon,
    this.titleMaxLines = 1,
    this.reorderable = true,
    this.selectionMode = false,
    this.isSelected = false,
  });

  /// 在 `ReorderableListView` 中的位置，供拖拽手柄定位。
  final int index;
  final String? coverUrl;
  final double coverWidth;
  final double coverAspectRatio;
  final String title;
  final bool isHovered;
  final VoidCallback onTap;
  final Key menuKey;
  final Key dragHandleKey;
  final VoidCallback onRemove;
  final String? subtitle;
  final VoidCallback? onOpenSource;
  final String? openSourceLabel;
  final BoxFit coverFit;
  final IconData? placeholderIcon;
  final int titleMaxLines;

  /// 是否允许拖拽重排：为 `false` 时隐藏拖拽手柄（仅在 `ReorderableListView` 中才应为
  /// `true`，否则手柄的 `ReorderableDragStartListener` 找不到上层控制器会报错）。
  final bool reorderable;

  /// 选择模式：整行点击切换选中，左侧显示复选框，隐藏拖拽手柄与「···」菜单。
  final bool selectionMode;

  /// 当前是否被选中（仅 [selectionMode] 下有意义）。
  final bool isSelected;

  @override
  Widget build(BuildContext context) {
    final spacing = context.appSpacing;
    final colors = context.appColors;
    final url = coverUrl?.trim();
    final sub = subtitle?.trim();
    final borderColor = selectionMode && isSelected
        ? colors.selectionBorder
        : colors.borderSubtle;

    return Material(
      color: colors.surfaceCard,
      borderRadius: context.appRadius.mdBorder,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        borderRadius: context.appRadius.mdBorder,
        onTap: onTap,
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: context.appRadius.mdBorder,
            border: Border.all(
              color: borderColor,
              width: selectionMode && isSelected ? 2 : 1,
            ),
          ),
          child: Row(
            children: [
              if (selectionMode) ...[
                SizedBox(width: spacing.sm),
                Checkbox(
                  value: isSelected,
                  onChanged: (_) => onTap(),
                ),
              ],
              // 缩略图贴满卡片左侧，圆角由外层 Material 统一裁剪。
              SizedBox(
                width: coverWidth,
                child: AspectRatio(
                  aspectRatio: coverAspectRatio,
                  child: url != null && url.isNotEmpty
                      ? MaskedImage(url: url, fit: coverFit)
                      : _CoverPlaceholder(
                          icon: placeholderIcon,
                          iconSize: context.appComponentTokens.iconSizeSm,
                        ),
                ),
              ),
              SizedBox(width: spacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      title,
                      maxLines: titleMaxLines,
                      overflow: TextOverflow.ellipsis,
                      style: resolveAppTextStyle(
                        context,
                        size: AppTextSize.s14,
                        weight: AppTextWeight.semibold,
                        tone: AppTextTone.primary,
                      ),
                    ),
                    if (sub != null && sub.isNotEmpty) ...[
                      SizedBox(height: spacing.xs),
                      Text(
                        sub,
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
                  ],
                ),
              ),
              SizedBox(width: spacing.sm),
              // 选择模式下隐藏拖拽手柄与「···」菜单，避免与多选交互冲突。
              if (!selectionMode) ...[
                // 拖拽手柄：仅手动顺序（[reorderable]）下渲染，悬停时显现，
                // 参照「播放列表」页的右侧圆形手柄。
                if (reorderable) ...[
                  Visibility(
                    visible: isHovered,
                    maintainSize: true,
                    maintainAnimation: true,
                    maintainState: true,
                    child: IgnorePointer(
                      ignoring: !isHovered,
                      child: ReorderableDragStartListener(
                        index: index,
                        child: MouseRegion(
                          cursor: SystemMouseCursors.grab,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: colors.surfaceCard.withValues(alpha: 0.92),
                              shape: BoxShape.circle,
                              border: Border.all(color: colors.borderSubtle),
                            ),
                            child: Padding(
                              padding: EdgeInsets.all(spacing.xs),
                              child: Icon(
                                Icons.unfold_more_rounded,
                                key: dragHandleKey,
                                size: context.appComponentTokens.iconSizeMd,
                                color: context.appTextPalette.primary,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: spacing.sm),
                ],
                CollectionMemberMenu(
                  menuKey: menuKey,
                  onCover: false,
                  onOpenSource: onOpenSource,
                  openSourceLabel: openSourceLabel,
                  onRemove: onRemove,
                ),
                SizedBox(width: spacing.sm),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// 合集成员的网格卡。两种模式由 [overlayCaption] 切换：
/// - `false`（默认，上图下文）：横版封面在上、标题/副信息在下，适合 16:9 切片封面；
/// - `true`（标题压图）：整卡即封面、标题/副信息浮在底部渐变上，适合竖版海报，无下方留白。
///
/// 封面含播放遮罩 + 右上角更多菜单；上图下文模式还可选右下角徽标 [coverBadge]。
/// 点按触发 [onTap]（通常为从该位置连播整个合集）。
class CollectionMemberCard extends StatelessWidget {
  const CollectionMemberCard({
    super.key,
    required this.coverUrl,
    required this.coverAspectRatio,
    required this.title,
    required this.onTap,
    required this.menuKey,
    required this.onRemove,
    this.subtitle,
    this.onOpenSource,
    this.openSourceLabel,
    this.coverFit = BoxFit.cover,
    this.placeholderIcon,
    this.coverBadge,
    this.titleMaxLines = 1,
    this.overlayCaption = false,
    this.selectionMode = false,
    this.isSelected = false,
  });

  final String? coverUrl;
  final double coverAspectRatio;
  final String title;
  final VoidCallback onTap;
  final Key menuKey;
  final VoidCallback onRemove;
  final String? subtitle;
  final VoidCallback? onOpenSource;
  final String? openSourceLabel;
  final BoxFit coverFit;
  final IconData? placeholderIcon;

  /// 封面右下角徽标（如切片时长 `ClipDurationBadge`）；仅上图下文模式生效，为 `null` 时不展示。
  final Widget? coverBadge;
  final int titleMaxLines;

  /// 是否把标题/副信息压在封面底部（竖版海报用，整卡即封面、无下方留白）。
  final bool overlayCaption;

  /// 选择模式：整卡点击切换选中，左上角显示勾选标记，隐藏「···」菜单。
  final bool selectionMode;

  /// 当前是否被选中（仅 [selectionMode] 下有意义）。
  final bool isSelected;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final spacing = context.appSpacing;
    final borderColor = selectionMode && isSelected
        ? colors.selectionBorder
        : colors.borderSubtle;
    final content =
        overlayCaption ? _buildOverlay(context) : _buildBelow(context);
    return Material(
      color: colors.surfaceCard,
      borderRadius: context.appRadius.mdBorder,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: context.appRadius.mdBorder,
            border: Border.all(
              color: borderColor,
              width: selectionMode && isSelected ? 2 : 1,
            ),
          ),
          child: selectionMode
              ? Stack(
                  children: [
                    content,
                    Positioned(
                      top: spacing.xs,
                      left: spacing.xs,
                      child: IgnorePointer(
                        child: _MemberSelectionCheck(isSelected: isSelected),
                      ),
                    ),
                  ],
                )
              : content,
        ),
      ),
    );
  }

  Widget _buildCover(BuildContext context) {
    final url = coverUrl?.trim();
    if (url != null && url.isNotEmpty) {
      return MaskedImage(url: url, fit: coverFit);
    }
    return _CoverPlaceholder(
      icon: placeholderIcon,
      iconSize: context.appComponentTokens.iconSize3xl,
    );
  }

  Widget _buildMenu() => selectionMode
      ? const SizedBox.shrink()
      : CollectionMemberMenu(
          menuKey: menuKey,
          onOpenSource: onOpenSource,
          openSourceLabel: openSourceLabel,
          onRemove: onRemove,
        );

  /// 上图下文：封面在上、标题/副信息在下。
  Widget _buildBelow(BuildContext context) {
    final spacing = context.appSpacing;
    final sub = subtitle?.trim();
    final badge = coverBadge;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        AspectRatio(
          aspectRatio: coverAspectRatio,
          child: Stack(
            fit: StackFit.expand,
            children: [
              _buildCover(context),
              const _MemberPlayOverlay(),
              if (badge != null)
                Positioned(right: spacing.xs, bottom: spacing.xs, child: badge),
              Positioned(
                right: spacing.xs,
                top: spacing.xs,
                child: _buildMenu(),
              ),
            ],
          ),
        ),
        Padding(
          padding: EdgeInsets.all(spacing.sm),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                maxLines: titleMaxLines,
                overflow: TextOverflow.ellipsis,
                style: resolveAppTextStyle(
                  context,
                  size: AppTextSize.s14,
                  weight: AppTextWeight.semibold,
                  tone: AppTextTone.primary,
                ),
              ),
              if (sub != null && sub.isNotEmpty) ...[
                SizedBox(height: spacing.xs),
                Text(
                  sub,
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
            ],
          ),
        ),
      ],
    );
  }

  /// 标题压图：整卡即封面，标题/副信息浮在底部渐变上。
  Widget _buildOverlay(BuildContext context) {
    final spacing = context.appSpacing;
    final sub = subtitle?.trim();
    return AspectRatio(
      aspectRatio: coverAspectRatio,
      child: Stack(
        fit: StackFit.expand,
        children: [
          _buildCover(context),
          const _MemberCaptionShade(),
          const _MemberPlayOverlay(),
          Positioned(
            left: spacing.md,
            right: spacing.md,
            bottom: spacing.md,
            child: IgnorePointer(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    maxLines: titleMaxLines,
                    overflow: TextOverflow.ellipsis,
                    style: resolveAppTextStyle(
                      context,
                      size: AppTextSize.s14,
                      weight: AppTextWeight.semibold,
                      tone: AppTextTone.onMedia,
                    ),
                  ),
                  if (sub != null && sub.isNotEmpty) ...[
                    SizedBox(height: spacing.xs),
                    Text(
                      sub,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: resolveAppTextStyle(
                        context,
                        size: AppTextSize.s12,
                        weight: AppTextWeight.regular,
                        tone: AppTextTone.onMedia,
                      ).copyWith(color: Colors.white.withValues(alpha: 0.72)),
                    ),
                  ],
                ],
              ),
            ),
          ),
          Positioned(
            right: spacing.xs,
            top: spacing.xs,
            child: _buildMenu(),
          ),
        ],
      ),
    );
  }
}

/// 标题压图模式下封面底部的渐变，保证浮层白字可读。
class _MemberCaptionShade extends StatelessWidget {
  const _MemberCaptionShade();

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return IgnorePointer(
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              colors.mediaOverlaySoft.withValues(alpha: 0),
              colors.mediaOverlaySoft,
              colors.mediaOverlayStrong,
            ],
            stops: const [0.45, 0.72, 1],
          ),
        ),
      ),
    );
  }
}

/// 封面缺图时的占位：muted 底色，可选居中图标（[icon] 为 `null` 时纯色）。
class _CoverPlaceholder extends StatelessWidget {
  const _CoverPlaceholder({required this.icon, required this.iconSize});

  final IconData? icon;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final iconData = icon;
    return DecoratedBox(
      decoration: BoxDecoration(color: colors.surfaceMuted),
      child: iconData == null
          ? null
          : Center(
              child: Icon(
                iconData,
                size: iconSize,
                color: context.appTextPalette.muted,
              ),
            ),
    );
  }
}

/// 选择模式下网格卡左上角的勾选标记：选中为实心对勾，未选为半透明空心圈。
class _MemberSelectionCheck extends StatelessWidget {
  const _MemberSelectionCheck({required this.isSelected});

  final bool isSelected;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Container(
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isSelected
            ? colors.selectionBorder
            : Colors.black.withValues(alpha: 0.35),
        border: Border.all(color: Colors.white, width: 1.5),
      ),
      child: isSelected
          ? const Icon(Icons.check, color: Colors.white, size: 14)
          : null,
    );
  }
}

/// 网格卡封面上的播放遮罩：半透明暗层 + 居中播放图标。
class _MemberPlayOverlay extends StatelessWidget {
  const _MemberPlayOverlay();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.16)),
      child: Center(
        child: Icon(
          Icons.play_circle_outline_rounded,
          color: Colors.white.withValues(alpha: 0.92),
          size: context.appComponentTokens.iconSize2xl,
        ),
      ),
    );
  }
}
