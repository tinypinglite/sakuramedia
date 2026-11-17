import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/features/clips/data/dto/media_clip_dto.dart';
import 'package:sakuramedia/l10n/app_localizations.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/interaction/app_context_menu_trigger.dart';
import 'package:sakuramedia/widgets/base/interaction/app_cover_hover_info.dart';
import 'package:sakuramedia/widgets/base/interaction/app_interactive_surface.dart';
import 'package:sakuramedia/widgets/base/layout/cards/app_cover_card.dart';
import 'package:sakuramedia/widgets/base/media/images/masked_image.dart';
import 'package:sakuramedia/widgets/base/overlays/app_action_menu.dart';

enum _ClipCardAction { openMovie, addToCollection, rename, delete }

/// 切片卡：整卡即封面，桌面端指针悬停时底部渐显单行「标题 + 番号 · 时长 ·
/// 大小」与靠右的播放按钮，收起态不铺任何文字。
///
/// 桌面 grid 版本单击弹操作弹窗 + 右键 / 长按弹菜单；移动 cover 版本
/// （见 [ClipCoverCard] 薄壳）整卡点击弹操作抽屉、无右键菜单、无悬停展开。
///
/// 选择模式下整卡点击切换选中、屏蔽右键菜单与 tap、左上角叠勾选。
class ClipGridCard extends StatelessWidget {
  const ClipGridCard({
    super.key,
    required this.clip,
    required this.onTap,
    this.onPlay,
    this.onRename,
    this.onDelete,
    this.onAddToCollection,
    this.onOpenMovie,
    this.selectionMode = false,
    this.isSelected = false,
    this.onSelectedChanged,
    this.onLongPress,
    this.tapKey,
  });

  final MediaClipDto clip;

  /// 整卡点击回调:桌面 = 弹操作弹窗;移动 cover 版 = 弹抽屉。
  final VoidCallback onTap;

  /// 悬停面板里的播放主按钮回调;为 `null` 时不显示按钮。
  final VoidCallback? onPlay;

  /// 菜单相关回调,全部可空。任一非空 + 非选择模式 = 加右键 / 长按手势。
  final VoidCallback? onRename;
  final VoidCallback? onDelete;
  final VoidCallback? onAddToCollection;

  /// 跳转到切片来源影片详情;切片无番号 / cover 版本不适用时为 `null`。
  final VoidCallback? onOpenMovie;

  final bool selectionMode;
  final bool isSelected;
  final ValueChanged<bool>? onSelectedChanged;

  /// 整卡长按（移动端进入多选）；走 [AppInteractiveSurface] 的统一触感，
  /// 调用方不要再自己包 `GestureDetector`。
  final VoidCallback? onLongPress;

  /// InkWell Key,测试锚点。桌面 grid 传 `clip-grid-card-tap-<id>`,
  /// 移动 cover 薄壳传 `clip-cover-card-<id>`。
  final Key? tapKey;

  bool get _hasMenu =>
      onRename != null ||
      onDelete != null ||
      onAddToCollection != null ||
      onOpenMovie != null;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final coverUrl = clip.coverImage?.origin;
    final handleTap = selectionMode
        ? onSelectedChanged == null
              ? null
              : () => onSelectedChanged!(!isSelected)
        : onTap;

    final card = AppInteractiveSurface(
      key: tapKey,
      onTap: handleTap,
      onLongPress: onLongPress,
      child: AppCoverCard(
        coverAspectRatio: 16 / 9,
        hoverEnabled: !selectionMode,
        selectionMode: selectionMode,
        isSelected: isSelected,
        cover: coverUrl != null && coverUrl.isNotEmpty
            ? MaskedImage(url: coverUrl, fit: BoxFit.cover)
            : ColoredBox(color: colors.surfaceMuted),
        infoBuilder: (context) => _buildHoverInfo(context),
      ),
    );

    if (selectionMode || !_hasMenu) {
      return card;
    }
    return AppContextMenuTrigger(
      onRequestMenu: (position) => _showContextMenu(context, position),
      child: card,
    );
  }

  /// 悬停展开内容：单行「标题 + 番号 · 时长 · 大小」，下方一整行动作按钮
  /// （播放 / 影片 / 加入合集 / 重命名 / 删除，按回调是否为空显隐）。
  Widget _buildHoverInfo(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AppCoverHoverPanel(
      info: AppCoverHoverInfoRow(
        key: Key('clip-grid-card-info-${clip.clipId}'),
        label: clip.displayTitle(l10n),
        meta: clip.metaLine(l10n),
      ),
      actions: [
        if (onPlay != null)
          AppCoverHoverActionButton(
            key: Key('clip-grid-card-play-${clip.clipId}'),
            icon: Icons.play_arrow_rounded,
            onTap: onPlay,
            primary: true,
            tooltip: l10n.widgetClipActionPlay,
          ),
        if (onOpenMovie != null)
          AppCoverHoverActionButton(
            key: Key('clip-grid-card-movie-${clip.clipId}'),
            icon: Icons.movie_outlined,
            onTap: onOpenMovie,
            tooltip: l10n.widgetClipActionMovie,
          ),
        if (onAddToCollection != null)
          AppCoverHoverActionButton(
            key: Key('clip-grid-card-add-collection-${clip.clipId}'),
            icon: Icons.playlist_add_rounded,
            onTap: onAddToCollection,
            tooltip: l10n.widgetClipActionAddToCollection,
          ),
        if (onRename != null)
          AppCoverHoverActionButton(
            key: Key('clip-grid-card-rename-${clip.clipId}'),
            icon: Icons.edit_outlined,
            onTap: onRename,
            tooltip: l10n.widgetClipActionRename,
          ),
        if (onDelete != null)
          AppCoverHoverActionButton(
            key: Key('clip-grid-card-delete-${clip.clipId}'),
            icon: Icons.delete_outline_rounded,
            onTap: onDelete,
            tooltip: l10n.commonDelete,
          ),
      ],
    );
  }

  Future<void> _showContextMenu(
    BuildContext context,
    Offset globalPosition,
  ) async {
    final l10n = AppLocalizations.of(context);
    final action = await showAppActionMenu<_ClipCardAction>(
      context: context,
      globalPosition: globalPosition,
      items: [
        if (onOpenMovie != null)
          AppMenuItem(
            value: _ClipCardAction.openMovie,
            label: l10n.widgetClipActionMovie,
          ),
        if (onAddToCollection != null)
          AppMenuItem(
            value: _ClipCardAction.addToCollection,
            label: l10n.widgetClipActionAddToCollection,
          ),
        if (onRename != null)
          AppMenuItem(
            value: _ClipCardAction.rename,
            label: l10n.widgetClipActionRename,
          ),
        if (onDelete != null)
          AppMenuItem(
            value: _ClipCardAction.delete,
            label: l10n.commonDelete,
            tone: AppTextTone.error,
          ),
      ],
    );
    if (action == null) {
      return;
    }
    switch (action) {
      case _ClipCardAction.openMovie:
        onOpenMovie?.call();
      case _ClipCardAction.addToCollection:
        onAddToCollection?.call();
      case _ClipCardAction.rename:
        onRename?.call();
      case _ClipCardAction.delete:
        onDelete?.call();
    }
  }
}
