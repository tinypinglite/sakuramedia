import 'package:flutter/material.dart';
import 'package:sakuramedia/core/format/media_timecode.dart';
import 'package:sakuramedia/features/clips/data/dto/media_clip_dto.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/interaction/selection/selection_check_badge.dart';
import 'package:sakuramedia/widgets/base/media/images/masked_image.dart';
import 'package:sakuramedia/widgets/base/overlays/app_card_context_menu.dart';

enum _ClipCardAction { openMovie, addToCollection, rename, delete }

/// 切片卡：封面 + 底部一条信息条（左番号、右时长）。桌面 grid 版本
/// 单击播放 + 右键 / 长按弹菜单;移动 cover 版本(见 [ClipCoverCard]
/// 薄壳)整卡点击弹操作抽屉、无右键菜单。
///
/// 选择模式下整卡点击切换选中、屏蔽右键菜单与 tap、左上角叠勾选。
class ClipGridCard extends StatelessWidget {
  const ClipGridCard({
    super.key,
    required this.clip,
    required this.onTap,
    this.onRename,
    this.onDelete,
    this.onAddToCollection,
    this.onOpenMovie,
    this.selectionMode = false,
    this.isSelected = false,
    this.onSelectedChanged,
    this.tapKey,
    this.numberOverride,
    this.materialColor,
    this.backgroundOnDecoration = false,
  });

  final MediaClipDto clip;

  /// 整卡点击回调:桌面 = 播放;移动 cover 版 = 弹抽屉。
  final VoidCallback onTap;

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

  /// 番号显示 override。默认走 `movieNumber ?? '无番号'`(grid);
  /// cover 版传 `clip.displayNumber`。
  final String? numberOverride;

  /// [Material] 底色。cover 版传 `Colors.transparent`(外层已有背景);
  /// grid 版走默认 surfaceCard。
  final Color? materialColor;

  /// cover 版本外层没有额外背景,底色改到 [DecoratedBox] 上;grid 版走
  /// [Material] 底色即可。
  final bool backgroundOnDecoration;

  bool get _hasMenu =>
      onRename != null ||
      onDelete != null ||
      onAddToCollection != null ||
      onOpenMovie != null;

  @override
  Widget build(BuildContext context) {
    final spacing = context.appSpacing;
    final colors = context.appColors;
    final coverUrl = clip.coverImage?.bestAvailableUrl;
    final number = numberOverride ??
        (clip.movieNumber?.isNotEmpty == true ? clip.movieNumber! : '无番号');
    final duration = formatMediaTimecode(clip.durationSeconds);
    final labelTextStyle = resolveAppTextStyle(
      context,
      size: AppTextSize.s12,
      weight: AppTextWeight.regular,
      tone: AppTextTone.onMedia,
    );
    final selected = selectionMode && isSelected;

    final card = Material(
      color: materialColor ??
          (backgroundOnDecoration ? Colors.transparent : colors.surfaceCard),
      borderRadius: context.appRadius.mdBorder,
      child: InkWell(
        key: tapKey,
        borderRadius: context.appRadius.mdBorder,
        onTap: selectionMode
            ? () => onSelectedChanged?.call(!isSelected)
            : onTap,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: backgroundOnDecoration ? colors.surfaceCard : null,
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
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (coverUrl != null && coverUrl.isNotEmpty)
                    MaskedImage(url: coverUrl, fit: BoxFit.cover)
                  else
                    ColoredBox(color: colors.surfaceMuted),
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
                                number,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: labelTextStyle,
                              ),
                            ),
                            SizedBox(width: spacing.sm),
                            Text(duration, style: labelTextStyle),
                          ],
                        ),
                      ),
                    ),
                  ),
                  if (selectionMode)
                    Positioned(
                      top: spacing.xs,
                      left: spacing.xs,
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

  Future<void> _showContextMenu(
    BuildContext context,
    Offset globalPosition,
  ) async {
    final openMovie = onOpenMovie;
    final addToCollection = onAddToCollection;
    final rename = onRename;
    final delete = onDelete;
    final action = await showAppCardContextMenu<_ClipCardAction>(
      context,
      globalPosition: globalPosition,
      items: [
        if (openMovie != null)
          const AppCardContextMenuItem(
            value: _ClipCardAction.openMovie,
            label: '影片',
          ),
        if (addToCollection != null)
          const AppCardContextMenuItem(
            value: _ClipCardAction.addToCollection,
            label: '加入合集',
          ),
        if (rename != null)
          const AppCardContextMenuItem(
            value: _ClipCardAction.rename,
            label: '重命名',
          ),
        if (delete != null)
          const AppCardContextMenuItem(
            value: _ClipCardAction.delete,
            label: '删除',
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
