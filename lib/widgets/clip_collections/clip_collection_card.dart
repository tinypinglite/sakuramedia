import 'package:flutter/material.dart';
import 'package:sakuramedia/features/clip_collections/data/clip_collection_dto.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/media/masked_image.dart';

/// 切片合集封面卡：16:9 封面 + 名称 + 切片数，用于切片首页横滑与合集列表网格。
class ClipCollectionCard extends StatelessWidget {
  const ClipCollectionCard({
    super.key,
    required this.collection,
    required this.onTap,
    this.onEdit,
    this.onDelete,
  });

  final ClipCollectionDto collection;
  final VoidCallback onTap;

  /// 右上角「更多」菜单的编辑动作；与 [onDelete] 任一非空时展示「···」菜单。
  final VoidCallback? onEdit;

  /// 右上角「更多」菜单的删除动作。
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final spacing = context.appSpacing;
    final colors = context.appColors;
    final coverUrl = collection.coverImage?.bestAvailableUrl;

    return Material(
      color: colors.surfaceCard,
      borderRadius: context.appRadius.mdBorder,
      child: InkWell(
        key: Key('clip-collection-card-tap-${collection.id}'),
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
                      if (coverUrl != null && coverUrl.isNotEmpty)
                        MaskedImage(url: coverUrl, fit: BoxFit.cover)
                      else
                        ColoredBox(
                          color: colors.surfaceMuted,
                          child: Center(
                            child: Icon(
                              Icons.video_library_outlined,
                              color: colors.borderStrong,
                              size: context.appComponentTokens.iconSizeLg,
                            ),
                          ),
                        ),
                      Positioned(
                        right: spacing.xs,
                        bottom: spacing.xs,
                        child: _CountBadge(count: collection.clipCount),
                      ),
                      if (onEdit != null || onDelete != null)
                        Positioned(
                          right: spacing.xs,
                          top: spacing.xs,
                          child: _MoreMenu(
                            menuKey: Key('clip-collection-more-${collection.id}'),
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
                  collection.name,
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

  final Key menuKey;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withValues(alpha: 0.45),
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: PopupMenuButton<_CollectionMenuAction>(
        key: menuKey,
        tooltip: '更多',
        padding: EdgeInsets.zero,
        position: PopupMenuPosition.under,
        icon: const Padding(
          padding: EdgeInsets.all(4),
          child: Icon(Icons.more_horiz_rounded, color: Colors.white, size: 18),
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
    );
  }
}
