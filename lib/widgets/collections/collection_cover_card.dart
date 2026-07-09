import 'package:flutter/material.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/media/images/masked_image.dart';

/// 合集封面卡的共享实现：16:9 封面 + 底部标题 + 封面右下角计数角标。
///
/// 「编辑 / 删除」走**右键 / 长按**弹出的上下文菜单（与 [ClipGridCard]
/// `VideoSummaryCard` 等的右键菜单形式对齐），封面右上角不再渲染常显
/// 的「···」按钮。
///
/// 切片「我的合集」与视频合集结构完全一致，仅在 DTO、计数字段、占位图标、
/// 封面 `fit` 与 key 前缀上有差异，故由 [CollectionCard] 的 `.clip` / `.video`
/// 命名构造把各自的差异以参数喂入，避免两份近乎相同的卡片实现重复。
class CollectionCoverCard extends StatelessWidget {
  const CollectionCoverCard({
    super.key,
    required this.title,
    required this.count,
    required this.coverUrl,
    required this.onTap,
    this.tapKey,
    this.menuKey,
    this.coverFit = BoxFit.cover,
    this.placeholderIcon = Icons.video_library_outlined,
    this.onEdit,
    this.onDelete,
  });

  /// 合集名称（底部单行标题）。
  final String title;

  /// 封面右下角的计数（切片数 / 视频数）。
  final int count;

  /// 封面图地址；为空时显示占位图标。
  final String? coverUrl;

  final VoidCallback onTap;

  /// 整卡点击层（InkWell）的 key，供测试 / 自动化定位。
  final Key? tapKey;

  /// 包裹整卡、接右键 / 长按手势的外层节点 key，供测试 / 自动化触发上下文菜单。
  final Key? menuKey;

  /// 封面填充方式。横图缩略图用 [BoxFit.cover] 铺满；可能为竖图的封面用
  /// [BoxFit.contain] 完整展示、不裁切。
  final BoxFit coverFit;

  /// 无封面时的占位图标。
  final IconData placeholderIcon;

  /// 右键 / 长按菜单的「编辑」动作；与 [onDelete] 同为 `null` 时整卡不再接右键 / 长按。
  final VoidCallback? onEdit;

  /// 右键 / 长按菜单的「删除」动作。
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final spacing = context.appSpacing;
    final colors = context.appColors;
    final cover = coverUrl;

    final card = Material(
      color: colors.surfaceCard,
      borderRadius: context.appRadius.mdBorder,
      child: InkWell(
        key: tapKey,
        borderRadius: context.appRadius.mdBorder,
        onTap: onTap,
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: context.appRadius.mdBorder,
            border: Border.all(color: colors.borderSubtle),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.vertical(
                  top: Radius.circular(context.appRadius.md),
                ),
                child: AspectRatio(
                  aspectRatio: 16 / 9,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      // muted 底色：cover 时被封面盖满，contain 时填充留白。
                      ColoredBox(color: colors.surfaceMuted),
                      if (cover != null && cover.isNotEmpty)
                        MaskedImage(url: cover, fit: coverFit)
                      else
                        Center(
                          child: Icon(
                            placeholderIcon,
                            color: colors.borderStrong,
                            size: context.appComponentTokens.iconSizeLg,
                          ),
                        ),
                      Positioned(
                        right: spacing.xs,
                        bottom: spacing.xs,
                        child: _CountBadge(count: count),
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: EdgeInsets.all(spacing.sm),
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: resolveAppTextStyle(
                    context,
                    size: AppTextSize.s14,
                    weight: AppTextWeight.semibold,
                    tone: AppTextTone.primary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (onEdit == null && onDelete == null) {
      return card;
    }
    return GestureDetector(
      key: menuKey,
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
    final navigator = Navigator.of(context);
    final overlay = navigator.overlay!.context.findRenderObject() as RenderBox;
    final localPosition = overlay.globalToLocal(globalPosition);
    final position = RelativeRect.fromRect(
      Rect.fromPoints(localPosition, localPosition),
      Offset.zero & overlay.size,
    );
    final edit = onEdit;
    final delete = onDelete;
    final action = await showMenu<_CollectionMenuAction>(
      context: context,
      position: position,
      useRootNavigator: false,
      items: <PopupMenuEntry<_CollectionMenuAction>>[
        if (edit != null)
          PopupMenuItem<_CollectionMenuAction>(
            value: _CollectionMenuAction.edit,
            child: Text(
              '编辑',
              style: resolveAppTextStyle(context, size: AppTextSize.s14),
            ),
          ),
        if (delete != null)
          PopupMenuItem<_CollectionMenuAction>(
            value: _CollectionMenuAction.delete,
            child: Text(
              '删除',
              style: resolveAppTextStyle(context, size: AppTextSize.s14),
            ),
          ),
      ],
    );
    if (action == null) {
      return;
    }
    switch (action) {
      case _CollectionMenuAction.edit:
        edit?.call();
      case _CollectionMenuAction.delete:
        delete?.call();
    }
  }
}

class _CountBadge extends StatelessWidget {
  const _CountBadge({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.55),
        borderRadius: context.appRadius.xsBorder,
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: context.appSpacing.xs,
          vertical: context.appSpacing.xs,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.video_library_rounded,
              color: Colors.white,
              size: 12,
            ),
            SizedBox(width: context.appSpacing.xs),
            Text(
              '$count',
              style: resolveAppTextStyle(
                context,
                size: AppTextSize.s12,
                weight: AppTextWeight.medium,
                tone: AppTextTone.primary,
              ).copyWith(color: Colors.white),
            ),
          ],
        ),
      ),
    );
  }
}

enum _CollectionMenuAction { edit, delete }
