import 'package:flutter/material.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/media/masked_image.dart';
import 'package:sakuramedia/widgets/selection/selection_check_badge.dart';

/// 合集「成员」（切片 / 视频）在详情页的共享展示组件：列表行 [CollectionMemberRow]
/// 与网格卡 [CollectionMemberCard]。
///
/// 「打开来源 / 移出合集 / 删除本体」走**右键 / 长按**弹出的上下文菜单（与
/// [ClipGridCard]、`VideoSummaryCard` 等的右键菜单形式对齐），封面右上角与
/// 列表行尾不再渲染常显的「···」按钮。
///
/// 切片合集与视频合集详情页结构一致，仅在 DTO、封面比例、副信息、占位图标、
/// 菜单项与 key 前缀上有差异，由各详情页把差异以参数喂入，避免两份近乎相同的实现重复。
/// 与「合集封面卡」[CollectionCoverCard] 同属一套范式。
enum _MemberMenuAction { openSource, remove, delete }

/// 在 [globalPosition] 处弹出合集成员的上下文菜单。
///
/// 由 [CollectionMemberCard] / [CollectionMemberRow] 的右键 / 长按手势触发；
/// 任一动作回调为 `null` 时对应菜单项隐藏。`onRemove` 必须非空（无可移出动作时
/// 上层根本不该接右键 / 长按）。
Future<void> _showCollectionMemberContextMenu(
  BuildContext context, {
  required Offset globalPosition,
  required VoidCallback onRemove,
  required String removeLabel,
  VoidCallback? onOpenSource,
  String? openSourceLabel,
  VoidCallback? onDelete,
  String deleteLabel = '删除视频',
}) async {
  final navigator = Navigator.of(context);
  final overlay = navigator.overlay!.context.findRenderObject() as RenderBox;
  final localPosition = overlay.globalToLocal(globalPosition);
  final position = RelativeRect.fromRect(
    Rect.fromPoints(localPosition, localPosition),
    Offset.zero & overlay.size,
  );
  final openSource = onOpenSource;
  final label = openSourceLabel;
  final delete = onDelete;
  final action = await showMenu<_MemberMenuAction>(
    context: context,
    position: position,
    useRootNavigator: false,
    items: <PopupMenuEntry<_MemberMenuAction>>[
      if (openSource != null && label != null)
        PopupMenuItem<_MemberMenuAction>(
          value: _MemberMenuAction.openSource,
          child: Text(label),
        ),
      PopupMenuItem<_MemberMenuAction>(
        value: _MemberMenuAction.remove,
        // 无「删除本体」时（如切片合集）「移出合集」保持原有 error 强调色；与红色
        // 删除项并列时退为常规色，让破坏性的「删除」独占红色、层级清晰。
        child: Text(
          removeLabel,
          style: delete == null
              ? TextStyle(color: context.appTextPalette.error)
              : null,
        ),
      ),
      if (delete != null)
        PopupMenuItem<_MemberMenuAction>(
          value: _MemberMenuAction.delete,
          child: Text(
            deleteLabel,
            style: TextStyle(color: context.appTextPalette.error),
          ),
        ),
    ],
  );
  if (action == null) {
    return;
  }
  switch (action) {
    case _MemberMenuAction.openSource:
      openSource?.call();
    case _MemberMenuAction.remove:
      onRemove();
    case _MemberMenuAction.delete:
      delete?.call();
  }
}

/// 合集成员的列表行：封面贴满左侧 + 标题/副信息，悬停显现拖拽手柄。
/// 整行点击触发 [onTap]（通常为从该位置连播整个合集）；
/// 整行右键 / 长按弹「打开来源 / 移出合集 / 删除本体」上下文菜单。
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
    this.onRemove,
    this.onDelete,
    this.deleteLabel = '删除视频',
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

  /// 包裹整行、接右键 / 长按手势的外层节点 key，供测试 / 自动化触发上下文菜单。
  final Key menuKey;
  final Key dragHandleKey;

  /// 「移出合集」动作；为 `null` 时整行不接右键 / 长按（移动端整行点击弹抽屉的场景）。
  final VoidCallback? onRemove;

  /// 「删除本体」动作（如视频合集的「删除视频」）；为 `null` 时菜单不含该项。
  final VoidCallback? onDelete;

  /// 「删除本体」菜单项文案（如切片合集传「删除切片」）；默认「删除视频」。
  final String deleteLabel;
  final String? subtitle;
  final VoidCallback? onOpenSource;
  final String? openSourceLabel;
  final BoxFit coverFit;
  final IconData? placeholderIcon;
  final int titleMaxLines;

  /// 是否允许拖拽重排：为 `false` 时隐藏拖拽手柄（仅在 `ReorderableListView` 中才应为
  /// `true`，否则手柄的 `ReorderableDragStartListener` 找不到上层控制器会报错）。
  final bool reorderable;

  /// 选择模式：整行点击切换选中，左侧显示复选框，隐藏拖拽手柄；屏蔽右键 / 长按菜单。
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

    final row = Material(
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
              // 选择模式下隐藏拖拽手柄，避免与多选交互冲突。
              if (!selectionMode && reorderable) ...[
                // 拖拽手柄：仅手动顺序（[reorderable]）下渲染，悬停时显现，
                // 参照「播放列表」页的右侧圆形手柄。
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
            ],
          ),
        ),
      ),
    );

    final remove = onRemove;
    if (selectionMode || remove == null) {
      return row;
    }
    return GestureDetector(
      key: menuKey,
      behavior: HitTestBehavior.deferToChild,
      onSecondaryTapDown: (details) => _showCollectionMemberContextMenu(
        context,
        globalPosition: details.globalPosition,
        onRemove: remove,
        removeLabel: '移出合集',
        onOpenSource: onOpenSource,
        openSourceLabel: openSourceLabel,
        onDelete: onDelete,
        deleteLabel: deleteLabel,
      ),
      onLongPressStart: (details) => _showCollectionMemberContextMenu(
        context,
        globalPosition: details.globalPosition,
        onRemove: remove,
        removeLabel: '移出合集',
        onOpenSource: onOpenSource,
        openSourceLabel: openSourceLabel,
        onDelete: onDelete,
        deleteLabel: deleteLabel,
      ),
      child: row,
    );
  }
}

/// 合集成员的网格卡。三种模式由 [overlayCaption] / [clipOverlay] 切换：
/// - `false` / `false`（默认，上图下文）：横版封面在上、标题/副信息在下，适合 16:9 切片封面；
/// - `overlayCaption: true`（标题压图）：整卡即封面、标题/副信息浮在底部渐变上，适合竖版海报，无下方留白；
/// - `clipOverlay: true`（切片风格）：整卡即封面、底部半透明黑条展示左番号右时长，与 [ClipGridCard] 风格统一。
///
/// 封面含播放遮罩；上图下文模式还可选右下角徽标 [coverBadge]。
/// 整卡点击触发 [onTap]（通常为从该位置连播整个合集）；
/// 整卡右键 / 长按弹「打开来源 / 移出合集 / 删除本体」上下文菜单。
class CollectionMemberCard extends StatelessWidget {
  const CollectionMemberCard({
    super.key,
    required this.coverUrl,
    required this.coverAspectRatio,
    required this.title,
    required this.onTap,
    required this.menuKey,
    this.onRemove,
    this.onDelete,
    this.deleteLabel = '删除视频',
    this.subtitle,
    this.onOpenSource,
    this.openSourceLabel,
    this.coverFit = BoxFit.cover,
    this.placeholderIcon,
    this.coverBadge,
    this.titleMaxLines = 1,
    this.overlayCaption = false,
    this.clipOverlay = false,
    this.selectionMode = false,
    this.isSelected = false,
  });

  final String? coverUrl;
  final double coverAspectRatio;
  final String title;
  final VoidCallback onTap;

  /// 包裹整卡、接右键 / 长按手势的外层节点 key，供测试 / 自动化触发上下文菜单。
  final Key menuKey;

  /// 「移出合集」动作；为 `null` 时整卡不接右键 / 长按（移动端整卡点击弹抽屉的场景）。
  final VoidCallback? onRemove;

  /// 「删除本体」动作（如视频合集的「删除视频」）；为 `null` 时菜单不含该项。
  final VoidCallback? onDelete;

  /// 「删除本体」菜单项文案（如切片合集传「删除切片」）；默认「删除视频」。
  final String deleteLabel;
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

  /// 是否使用切片风格（底部半透明黑条 + 左番号右时长，与 [ClipGridCard] 统一）。
  final bool clipOverlay;

  /// 选择模式：整卡点击切换选中，左上角显示勾选标记；屏蔽右键 / 长按菜单。
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
    final content = clipOverlay
        ? _buildClipOverlay(context)
        : overlayCaption
            ? _buildOverlay(context)
            : _buildBelow(context);
    final radius =
        clipOverlay ? context.appRadius.lgBorder : context.appRadius.mdBorder;
    final shadow = clipOverlay ? context.appShadows.card : null;
    final card = Material(
      color: colors.surfaceCard,
      borderRadius: radius,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: radius,
            border: Border.all(
              color: borderColor,
              width: selectionMode && isSelected ? 2 : 1,
            ),
            boxShadow: shadow,
          ),
          child: selectionMode
              ? Stack(
                  children: [
                    content,
                    Positioned(
                      top: spacing.xs,
                      left: spacing.xs,
                      child: IgnorePointer(
                        child: SelectionCheckBadge(isSelected: isSelected),
                      ),
                    ),
                  ],
                )
              : content,
        ),
      ),
    );

    final remove = onRemove;
    if (selectionMode || remove == null) {
      return card;
    }
    return GestureDetector(
      key: menuKey,
      behavior: HitTestBehavior.deferToChild,
      onSecondaryTapDown: (details) => _showCollectionMemberContextMenu(
        context,
        globalPosition: details.globalPosition,
        onRemove: remove,
        removeLabel: '移出合集',
        onOpenSource: onOpenSource,
        openSourceLabel: openSourceLabel,
        onDelete: onDelete,
        deleteLabel: deleteLabel,
      ),
      onLongPressStart: (details) => _showCollectionMemberContextMenu(
        context,
        globalPosition: details.globalPosition,
        onRemove: remove,
        removeLabel: '移出合集',
        onOpenSource: onOpenSource,
        openSourceLabel: openSourceLabel,
        onDelete: onDelete,
        deleteLabel: deleteLabel,
      ),
      child: card,
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

  /// 切片风格：整卡即封面，番号/时长浮在底部半透明黑条上。
  Widget _buildClipOverlay(BuildContext context) {
    final spacing = context.appSpacing;
    final sub = subtitle?.trim();
    final labelTextStyle = resolveAppTextStyle(
      context,
      size: AppTextSize.s12,
      weight: AppTextWeight.regular,
      tone: AppTextTone.onMedia,
    );
    return ClipRRect(
      borderRadius: context.appRadius.lgBorder,
      child: AspectRatio(
        aspectRatio: coverAspectRatio,
        child: Stack(
          fit: StackFit.expand,
          children: [
            _buildCover(context),
            const _MemberPlayOverlay(),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.44),
                ),
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: spacing.md,
                    vertical: spacing.sm,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: labelTextStyle,
                        ),
                      ),
                      if (sub != null && sub.isNotEmpty) ...[
                        SizedBox(width: spacing.sm),
                        Text(sub, style: labelTextStyle),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
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
