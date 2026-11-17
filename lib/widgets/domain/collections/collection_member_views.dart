import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/l10n/app_localizations.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/interaction/app_context_menu_trigger.dart';
import 'package:sakuramedia/widgets/base/interaction/app_cover_hover_info.dart';
import 'package:sakuramedia/widgets/base/interaction/app_interactive_surface.dart';
import 'package:sakuramedia/widgets/base/layout/cards/app_cover_card.dart';
import 'package:sakuramedia/widgets/base/media/images/masked_image.dart';
import 'package:sakuramedia/widgets/base/overlays/app_action_menu.dart';

/// 合集「成员」（切片 / 视频）在详情页的共享网格卡 [CollectionMemberCard]。
///
/// 「打开来源 / 移出合集 / 删除本体」走**右键 / 长按**弹出的上下文菜单（与
/// [ClipGridCard]、`VideoSummaryCard` 等的右键菜单形式对齐），封面右上角不再
/// 渲染常显的「···」按钮；桌面悬停披露层则与列表页卡片一致，在信息行下方铺
/// 一整行动作按钮。
///
/// 切片合集与视频合集详情页结构一致，仅在 DTO、封面比例、副信息、菜单项
/// 与 key 前缀上有差异，由各详情页把差异以参数喂入，避免两份近乎相同的实现重复。
/// 与「合集封面卡」[CollectionCard] 同属一套范式。
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
  String? deleteLabel,
}) async {
  final openSource = onOpenSource;
  final label = openSourceLabel;
  final delete = onDelete;
  final resolvedDeleteLabel =
      deleteLabel ??
      AppLocalizations.of(context).widgetCollectionMemberDeleteVideo;
  final action = await showAppActionMenu<_MemberMenuAction>(
    context: context,
    globalPosition: globalPosition,
    items: [
      if (openSource != null && label != null)
        AppMenuItem(value: _MemberMenuAction.openSource, label: label),
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
          label: resolvedDeleteLabel,
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

/// 合集「成员」（切片 / 视频 / 时刻）在详情页的共享网格卡 [CollectionMemberCard]。
///
/// 整卡即封面、收起态不铺文字；桌面悬停时底部渐显单行标题/副信息与整行动作按钮
/// （播放 / 影片 / 缩略图 / 加入合集 / 移出合集 / 删除，按回调是否为空显隐），与
/// 全站封面卡片的悬停范式统一。移动端没有 hover，收起态停在纯封面，信息与动作走
/// 点击后的操作面板 / 预览层。
///
/// 「打开来源 / 移出合集 / 删除本体」走**右键 / 长按**弹出的上下文菜单（与
/// [ClipGridCard]、`VideoSummaryCard` 等的右键菜单形式对齐），封面右上角不再
/// 渲染常显的「···」按钮。
///
/// 整卡点击触发 [onTap]（通常为从该位置连播整个合集）。
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
    this.deleteLabel,
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
    this.selectionMode = false,
    this.isSelected = false,
    this.expandToParent = false,
    this.onLongPress,
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

  /// 「删除本体」菜单项文案（如切片合集传「删除切片」）；为空时用默认「删除视频」。
  final String? deleteLabel;

  /// 切片风格悬停面板里的播放键回调；为 `null` 时不显示按钮。
  final VoidCallback? onPlay;

  /// 悬停动作行的测试锚点。
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

  /// 选择模式：整卡点击切换选中，左上角显示勾选标记；屏蔽右键 / 长按菜单。
  final bool selectionMode;

  /// 当前是否被选中（仅 [selectionMode] 下有意义）。
  final bool isSelected;

  /// 卡片是否直接占满父布局尺寸（不再按 [coverAspectRatio] 自包 AspectRatio）。
  /// 瀑布流场景下父布局已按封面真实比例分配 tile 高度，再包 AspectRatio 会与父高度
  /// 冲突导致留空 / 溢出，此时传 `true` 让卡片直接 fit 父尺寸。
  final bool expandToParent;

  /// 整卡长按（移动端进入多选）；走 [AppInteractiveSurface] 的统一触感。
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final card = AppInteractiveSurface(
      onTap: onTap,
      onLongPress: onLongPress,
      child: AppCoverCard(
        coverAspectRatio: expandToParent ? null : coverAspectRatio,
        hoverEnabled: !selectionMode,
        selectionMode: selectionMode,
        isSelected: isSelected,
        cover: _buildCover(context),
        infoBuilder: (context) => _buildHoverInfo(context),
      ),
    );

    final remove = onRemove;
    if (selectionMode || remove == null) {
      return card;
    }
    return AppContextMenuTrigger(
      key: menuKey,
      onRequestMenu: (position) => _showCollectionMemberContextMenu(
        context,
        globalPosition: position,
        onRemove: remove,
        removeLabel: AppLocalizations.of(
          context,
        ).widgetCollectionMemberRemoveFromCollection,
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
    // 纯图片卡缺图态统一为 muted 纯色块：不带居中图标。
    return ColoredBox(color: context.appColors.surfaceMuted);
  }

  /// 悬停披露内容：单行标题/副信息与整行动作按钮（按回调显隐）。
  Widget _buildHoverInfo(BuildContext context) {
    final sub = subtitle?.trim();
    return AppCoverHoverPanel(
      info: AppCoverHoverInfoRow(label: title, meta: sub),
      actions: _buildHoverActions(context),
    );
  }

  /// 悬停动作行内容：按回调是否为空显隐，顺序与各动作弹窗一致。
  List<Widget> _buildHoverActions(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final resolvedDeleteLabel =
        deleteLabel ?? l10n.widgetCollectionMemberDeleteVideo;
    return <Widget>[
      if (onPlay != null)
        AppCoverHoverActionButton(
          key: playButtonKey,
          icon: Icons.play_arrow_rounded,
          onTap: onPlay,
          primary: true,
          tooltip: l10n.widgetCollectionMemberPlay,
        ),
      if (onOpenSource != null)
        AppCoverHoverActionButton(
          key: openSourceButtonKey,
          icon: Icons.movie_outlined,
          onTap: onOpenSource,
          tooltip: openSourceLabel ?? l10n.widgetCollectionMemberOpenMovie,
        ),
      if (onThumbnails != null)
        AppCoverHoverActionButton(
          key: thumbnailsButtonKey,
          icon: Icons.photo_library_outlined,
          onTap: onThumbnails,
          tooltip: l10n.widgetCollectionMemberThumbnails,
        ),
      if (onAddToCollection != null)
        AppCoverHoverActionButton(
          key: addToCollectionButtonKey,
          icon: Icons.playlist_add_rounded,
          onTap: onAddToCollection,
          tooltip: l10n.widgetCollectionMemberAddToCollection,
        ),
      if (onRemove != null)
        AppCoverHoverActionButton(
          key: removeButtonKey,
          icon: Icons.playlist_remove_rounded,
          onTap: onRemove,
          tooltip: l10n.widgetCollectionMemberRemoveFromCollection,
        ),
      if (onDelete != null)
        AppCoverHoverActionButton(
          key: deleteButtonKey,
          icon: Icons.delete_outline_rounded,
          onTap: onDelete,
          tooltip: resolvedDeleteLabel,
        ),
    ];
  }
}
