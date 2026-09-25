import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/features/clips/data/dto/media_clip_dto.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/interaction/app_cover_hover_info.dart';
import 'package:sakuramedia/widgets/base/interaction/selection/selection_check_badge.dart';
import 'package:sakuramedia/widgets/base/media/images/masked_image.dart';
import 'package:sakuramedia/widgets/base/overlays/app_action_menu.dart';
import 'package:skeletonizer/skeletonizer.dart';

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
    final coverUrl = clip.coverImage?.bestAvailableUrl;
    final selected = selectionMode && isSelected;

    final card = Material(
      color: colors.surfaceCard,
      borderRadius: context.appRadius.mdBorder,
      child: InkWell(
        mouseCursor: selectionMode && onSelectedChanged == null
            ? SystemMouseCursors.basic
            : SystemMouseCursors.click,
        key: tapKey,
        borderRadius: context.appRadius.mdBorder,
        onTap: selectionMode
            ? () => onSelectedChanged?.call(!isSelected)
            : onTap,
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: context.appRadius.mdBorder,
            border: Border.all(
              color: selected ? colors.selectionBorder : colors.borderSubtle,
              width: selected ? 2 : 1,
            ),
            boxShadow: context.appShadows.card,
          ),
          child: ClipRRect(
            borderRadius: context.appRadius.mdBorder,
            child: AspectRatio(
              aspectRatio: 16 / 9,
              // 骨架态整卡收敛成一块 shimmer 圆角块（非骨架态原样渲染）。
              child: Skeleton.unite(
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    AppCoverHoverInfo(
                      enabled: !selectionMode,
                      cover: coverUrl != null && coverUrl.isNotEmpty
                          ? MaskedImage(url: coverUrl, fit: BoxFit.cover)
                          : ColoredBox(color: colors.surfaceMuted),
                      infoBuilder: (context) => _buildHoverInfo(context),
                    ),
                    if (selectionMode)
                      Positioned(
                        top: context.appSpacing.xs,
                        left: context.appSpacing.xs,
                        child: IgnorePointer(
                          child: SelectionCheckBadge(isSelected: isSelected),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );

    if (selectionMode || !_hasMenu) {
      return card;
    }
    return GestureDetector(
      behavior: HitTestBehavior.deferToChild,
      onSecondaryTapDown: (details) =>
          _showContextMenu(context, details.globalPosition),
      onLongPressStart: (details) =>
          _showContextMenu(context, details.globalPosition),
      child: card,
    );
  }

  /// 悬停展开内容：单行「标题 + 番号 · 时长 · 大小」，下方一整行动作按钮
  /// （播放 / 影片 / 加入合集 / 重命名 / 删除，按回调是否为空显隐）。
  Widget _buildHoverInfo(BuildContext context) {
    final spacing = context.appSpacing;
    final play = onPlay;
    final openMovie = onOpenMovie;
    final addToCollection = onAddToCollection;
    final rename = onRename;
    final delete = onDelete;
    final actions = <Widget>[
      if (play != null)
        AppCoverHoverActionButton(
          key: Key('clip-grid-card-play-${clip.clipId}'),
          icon: Icons.play_arrow_rounded,
          onTap: play,
          primary: true,
          tooltip: '播放',
        ),
      if (openMovie != null)
        AppCoverHoverActionButton(
          key: Key('clip-grid-card-movie-${clip.clipId}'),
          icon: Icons.movie_outlined,
          onTap: openMovie,
          tooltip: '影片',
        ),
      if (addToCollection != null)
        AppCoverHoverActionButton(
          key: Key('clip-grid-card-add-collection-${clip.clipId}'),
          icon: Icons.playlist_add_rounded,
          onTap: addToCollection,
          tooltip: '加入合集',
        ),
      if (rename != null)
        AppCoverHoverActionButton(
          key: Key('clip-grid-card-rename-${clip.clipId}'),
          icon: Icons.edit_outlined,
          onTap: rename,
          tooltip: '重命名',
        ),
      if (delete != null)
        AppCoverHoverActionButton(
          key: Key('clip-grid-card-delete-${clip.clipId}'),
          icon: Icons.delete_outline_rounded,
          onTap: delete,
          tooltip: '删除',
        ),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        AppCoverHoverInfoRow(
          key: Key('clip-grid-card-info-${clip.clipId}'),
          label: clip.displayTitle,
          meta: clip.metaLine,
        ),
        if (actions.isNotEmpty) ...[
          SizedBox(height: spacing.sm),
          AppCoverHoverActionBar(actions: actions),
        ],
      ],
    );
  }

  Future<void> _showContextMenu(
    BuildContext context,
    Offset globalPosition,
  ) async {
    final openMovie = onOpenMovie;
    final addToCollection = onAddToCollection;
    final rename = onRename;
    final delete = onDelete;
    final action = await showAppActionMenu<_ClipCardAction>(
      context: context,
      globalPosition: globalPosition,
      items: [
        if (openMovie != null)
          const AppMenuItem(
            value: _ClipCardAction.openMovie,
            label: '影片',
          ),
        if (addToCollection != null)
          const AppMenuItem(
            value: _ClipCardAction.addToCollection,
            label: '加入合集',
          ),
        if (rename != null)
          const AppMenuItem(
            value: _ClipCardAction.rename,
            label: '重命名',
          ),
        if (delete != null)
          const AppMenuItem(
            value: _ClipCardAction.delete,
            label: '删除',
            tone: AppTextTone.error,
          ),
      ],
    );
    if (action == null) {
      return;
    }
    switch (action) {
      case _ClipCardAction.openMovie:
        openMovie?.call();
      case _ClipCardAction.addToCollection:
        addToCollection?.call();
      case _ClipCardAction.rename:
        rename?.call();
      case _ClipCardAction.delete:
        delete?.call();
    }
  }
}
