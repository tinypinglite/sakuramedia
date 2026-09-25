import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/interaction/app_cover_hover_info.dart';
import 'package:sakuramedia/widgets/base/interaction/selection/selection_check_badge.dart';
import 'package:sakuramedia/widgets/base/media/images/app_cover_bottom_shade.dart';
import 'package:sakuramedia/widgets/base/media/images/masked_image.dart';
import 'package:sakuramedia/widgets/base/overlays/app_action_menu.dart';

/// 合集「成员」（切片 / 视频）在详情页的共享网格卡 [CollectionMemberCard]。
///
/// 「打开来源 / 移出合集 / 删除本体」走**右键 / 长按**弹出的上下文菜单（与
/// [ClipGridCard]、`VideoSummaryCard` 等的右键菜单形式对齐），封面右上角不再
/// 渲染常显的「···」按钮；桌面悬停披露层则与列表页卡片一致，在信息行下方铺
/// 一整行动作按钮。
///
/// 切片合集与视频合集详情页结构一致，仅在 DTO、封面比例、副信息、占位图标、
/// 菜单项与 key 前缀上有差异，由各详情页把差异以参数喂入，避免两份近乎相同的实现重复。
/// 与「合集封面卡」[CollectionCoverCard] 同属一套范式。
enum _MemberMenuAction { openSource, remove, delete }

/// 在 [globalPosition] 处弹出合集成员的上下文菜单。
///
/// 由 [CollectionMemberCard] 的右键 / 长按手势触发；
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
  final openSource = onOpenSource;
  final label = openSourceLabel;
  final delete = onDelete;
  final action = await showAppActionMenu<_MemberMenuAction>(
    context: context,
    globalPosition: globalPosition,
    items: [
      if (openSource != null && label != null)
        AppMenuItem(
          value: _MemberMenuAction.openSource,
          label: label,
        ),
      // 无「删除本体」时（如切片合集）「移出合集」保持原有 error 强调色；与红色
      // 删除项并列时退为常规色，让破坏性的「删除」独占红色、层级清晰。
      AppMenuItem(
        value: _MemberMenuAction.remove,
        label: removeLabel,
        tone: delete == null ? AppTextTone.error : AppTextTone.primary,
      ),
      if (delete != null)
        AppMenuItem(
          value: _MemberMenuAction.delete,
          label: deleteLabel,
          tone: AppTextTone.error,
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

/// 合集成员的网格卡。三种模式由 [overlayCaption] / [clipOverlay] 切换：
/// - `false` / `false`（默认，上图下文）：横版封面在上、标题/副信息在下，适合 16:9 切片封面；
/// - `overlayCaption: true`（标题压图）：整卡即封面、标题/副信息浮在底部渐变上，适合竖版海报，无下方留白；
/// - `clipOverlay: true`（切片风格）：整卡即封面、收起态不铺文字，桌面悬停时底部渐显
///   标题/副信息与动作行（播放 / 影片 / 缩略图 / 加入合集 / 移出合集 / 删除，
///   按回调是否为空显隐），与全站封面卡片的悬停范式统一。
///
/// 上图下文模式还可选右下角徽标 [coverBadge]。
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
    this.onPlay,
    this.playButtonKey,
    this.subtitle,
    this.onOpenSource,
    this.openSourceLabel,
    this.onThumbnails,
    this.onAddToCollection,
    this.openSourceButtonKey,
    this.thumbnailsButtonKey,
    this.addToCollectionButtonKey,
    this.removeButtonKey,
    this.deleteButtonKey,
    this.coverFit = BoxFit.cover,
    this.placeholderIcon,
    this.coverBadge,
    this.titleMaxLines = 1,
    this.overlayCaption = false,
    this.clipOverlay = false,
    this.selectionMode = false,
    this.isSelected = false,
    this.expandToParent = false,
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

  /// 切片风格悬停面板里的播放键回调；为 `null` 时不显示按钮。
  final VoidCallback? onPlay;

  /// 悬停动作行的测试锚点；仅 [clipOverlay] 模式生效。
  final Key? playButtonKey;
  final String? subtitle;
  final VoidCallback? onOpenSource;
  final String? openSourceLabel;

  /// 「缩略图」动作（视频合集）；为 `null` 时悬停面板不显示该按钮。
  final VoidCallback? onThumbnails;

  /// 「加入合集」动作（加入其它合集）；为 `null` 时悬停面板不显示该按钮。
  final VoidCallback? onAddToCollection;

  final Key? openSourceButtonKey;
  final Key? thumbnailsButtonKey;
  final Key? addToCollectionButtonKey;
  final Key? removeButtonKey;
  final Key? deleteButtonKey;
  final BoxFit coverFit;
  final IconData? placeholderIcon;

  /// 封面右下角徽标（如切片时长 `MediaDurationBadge`）；仅上图下文模式生效，为 `null` 时不展示。
  final Widget? coverBadge;
  final int titleMaxLines;

  /// 是否把标题/副信息压在封面底部（竖版海报用，整卡即封面、无下方留白）。
  final bool overlayCaption;

  /// 是否使用切片风格（整卡即封面，收起态无文字；桌面悬停渐显标题/副信息与
  /// 播放键，与 [ClipGridCard] 统一）。
  final bool clipOverlay;

  /// 选择模式：整卡点击切换选中，左上角显示勾选标记；屏蔽右键 / 长按菜单。
  final bool selectionMode;

  /// 当前是否被选中（仅 [selectionMode] 下有意义）。
  final bool isSelected;

  /// 卡片是否直接占满父布局尺寸（不再按 [coverAspectRatio] 自包 AspectRatio）。
  /// 瀑布流场景下父布局已按封面真实比例分配 tile 高度，再包 AspectRatio 会与父高度
  /// 冲突导致留空 / 溢出，此时传 `true` 让卡片直接 fit 父尺寸。[overlayCaption]
  /// 与 [clipOverlay] 模式生效（上图下文仍依赖 AspectRatio 隔离封面区与下方文案）。
  final bool expandToParent;

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
    final radius = clipOverlay
        ? context.appRadius.lgBorder
        : context.appRadius.mdBorder;
    final shadow = clipOverlay ? context.appShadows.card : null;
    final card = Material(
      color: colors.surfaceCard,
      borderRadius: radius,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        mouseCursor: SystemMouseCursors.click,
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

  /// 切片风格：整卡即封面，收起态不铺文字；桌面悬停时底部渐显单行
  /// 标题/副信息与整行动作按钮（按回调显隐）。
  Widget _buildClipOverlay(BuildContext context) {
    final overlay = _buildClipOverlayStack(context);
    if (expandToParent) {
      return overlay;
    }
    return AspectRatio(aspectRatio: coverAspectRatio, child: overlay);
  }

  Widget _buildClipOverlayStack(BuildContext context) {
    final spacing = context.appSpacing;
    final sub = subtitle?.trim();
    final actions = _buildHoverActions();
    return ClipRRect(
      borderRadius: context.appRadius.lgBorder,
      child: Stack(
        fit: StackFit.expand,
        children: [
          AppCoverHoverInfo(
            enabled: !selectionMode,
            cover: _buildCover(context),
            infoBuilder: (context) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                AppCoverHoverInfoRow(label: title, meta: sub),
                if (actions.isNotEmpty) ...[
                  SizedBox(height: spacing.sm),
                  AppCoverHoverActionBar(actions: actions),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 悬停动作行内容：按回调是否为空显隐，顺序与各动作弹窗一致。
  List<Widget> _buildHoverActions() {
    return <Widget>[
      if (onPlay != null)
        AppCoverHoverActionButton(
          key: playButtonKey,
          icon: Icons.play_arrow_rounded,
          onTap: onPlay,
          primary: true,
          tooltip: '播放',
        ),
      if (onOpenSource != null)
        AppCoverHoverActionButton(
          key: openSourceButtonKey,
          icon: Icons.movie_outlined,
          onTap: onOpenSource,
          tooltip: openSourceLabel ?? '影片',
        ),
      if (onThumbnails != null)
        AppCoverHoverActionButton(
          key: thumbnailsButtonKey,
          icon: Icons.photo_library_outlined,
          onTap: onThumbnails,
          tooltip: '缩略图',
        ),
      if (onAddToCollection != null)
        AppCoverHoverActionButton(
          key: addToCollectionButtonKey,
          icon: Icons.playlist_add_rounded,
          onTap: onAddToCollection,
          tooltip: '加入合集',
        ),
      if (onRemove != null)
        AppCoverHoverActionButton(
          key: removeButtonKey,
          icon: Icons.playlist_remove_rounded,
          onTap: onRemove,
          tooltip: '移出合集',
        ),
      if (onDelete != null)
        AppCoverHoverActionButton(
          key: deleteButtonKey,
          icon: Icons.delete_outline_rounded,
          onTap: onDelete,
          tooltip: deleteLabel,
        ),
    ];
  }

  /// 标题压图：整卡即封面，标题/副信息浮在底部渐变上。
  Widget _buildOverlay(BuildContext context) {
    final spacing = context.appSpacing;
    final sub = subtitle?.trim();
    final stack = Stack(
      fit: StackFit.expand,
      children: [
        _buildCover(context),
        const AppCoverBottomShade(),
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
    );
    if (expandToParent) {
      return stack;
    }
    return AspectRatio(aspectRatio: coverAspectRatio, child: stack);
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
