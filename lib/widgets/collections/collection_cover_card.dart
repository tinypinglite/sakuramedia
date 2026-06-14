import 'package:flutter/material.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/media/masked_image.dart';

/// 合集封面卡的共享实现：16:9 封面 + 底部标题 + 封面右下角计数角标，
/// 右上角可选「···」菜单（编辑 / 删除）。
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

  /// 右上角「···」菜单按钮的 key。
  final Key? menuKey;

  /// 封面填充方式。横图缩略图用 [BoxFit.cover] 铺满；可能为竖图的封面用
  /// [BoxFit.contain] 完整展示、不裁切。
  final BoxFit coverFit;

  /// 无封面时的占位图标。
  final IconData placeholderIcon;

  /// 右上角「更多」菜单的编辑动作；与 [onDelete] 任一非空时展示「···」菜单。
  final VoidCallback? onEdit;

  /// 右上角「更多」菜单的删除动作。
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final spacing = context.appSpacing;
    final colors = context.appColors;
    final cover = coverUrl;

    return Material(
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
                      if (onEdit != null || onDelete != null)
                        Positioned(
                          right: spacing.xs,
                          top: spacing.xs,
                          child: _MoreMenu(
                            menuKey: menuKey,
                            onEdit: onEdit,
                            onDelete: onDelete,
                          ),
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

class _MoreMenu extends StatelessWidget {
  const _MoreMenu({required this.menuKey, this.onEdit, this.onDelete});

  final Key? menuKey;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 26,
      height: 26,
      child: Material(
        color: Colors.black.withValues(alpha: 0.45),
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: PopupMenuButton<_CollectionMenuAction>(
          key: menuKey,
          tooltip: '更多',
          padding: EdgeInsets.zero,
          iconSize: 16,
          position: PopupMenuPosition.under,
          icon: const Icon(
            Icons.more_horiz_rounded,
            color: Colors.white,
            size: 16,
          ),
          onSelected: (action) {
            switch (action) {
              case _CollectionMenuAction.edit:
                onEdit?.call();
              case _CollectionMenuAction.delete:
                onDelete?.call();
            }
          },
          itemBuilder:
              (context) => <PopupMenuEntry<_CollectionMenuAction>>[
                if (onEdit != null)
                  const PopupMenuItem<_CollectionMenuAction>(
                    value: _CollectionMenuAction.edit,
                    child: Text('编辑'),
                  ),
                if (onDelete != null)
                  const PopupMenuItem<_CollectionMenuAction>(
                    value: _CollectionMenuAction.delete,
                    child: Text('删除'),
                  ),
              ],
        ),
      ),
    );
  }
}
