import 'package:flutter/material.dart';
import 'package:sakuramedia/features/videos/data/dto/video_item_list_item_dto.dart';
import 'package:sakuramedia/theme.dart';

/// 视频「所属合集」的可点击胶囊组：
///
/// - 空列表 → 直接返回 `SizedBox.shrink()`，由调用方决定要不要外围留白；
/// - 非空 → `Wrap` 布局，每项是一个 `Icons.folder_outlined` + 合集名的胶囊；
/// - 点击某项 → 调 [onCollectionTap]，跳转由调用方决定（桌面走
///   `context.pushDesktopVideoCollectionDetail`，移动走
///   `MobileVideoCollectionDetailRouteData(...).push(context)`）。
///
/// 视觉刻意克制：`surfaceMuted` 底 + `borderSubtle` 描边 + s12/secondary 文字，
/// 归属信息是**辅助层级**，不与主视觉（封面、标题、播放按钮）抢注意力。
class VideoCollectionChips extends StatelessWidget {
  const VideoCollectionChips({
    super.key,
    required this.collections,
    required this.onCollectionTap,
  });

  final List<VideoCollectionRef> collections;
  final ValueChanged<VideoCollectionRef> onCollectionTap;

  @override
  Widget build(BuildContext context) {
    if (collections.isEmpty) {
      return const SizedBox.shrink();
    }
    final spacing = context.appSpacing;
    return Wrap(
      spacing: spacing.xs,
      runSpacing: spacing.xs,
      children: [
        for (final ref in collections)
          _VideoCollectionChip(
            key: Key('video-collection-chip-${ref.id}'),
            collection: ref,
            onTap: () => onCollectionTap(ref),
          ),
      ],
    );
  }
}

class _VideoCollectionChip extends StatelessWidget {
  const _VideoCollectionChip({
    super.key,
    required this.collection,
    required this.onTap,
  });

  final VideoCollectionRef collection;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final spacing = context.appSpacing;
    final tokens = context.appComponentTokens;
    final textPalette = context.appTextPalette;

    final label = collection.name.trim().isEmpty ? '未命名合集' : collection.name;

    return Material(
      color: colors.surfaceMuted,
      shape: RoundedRectangleBorder(
        borderRadius: context.appRadius.pillBorder,
        side: BorderSide(color: colors.borderSubtle),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: spacing.sm,
            vertical: spacing.xs,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.folder_outlined,
                size: tokens.iconSize3xs,
                color: textPalette.secondary,
              ),
              SizedBox(width: spacing.xs),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: resolveAppTextStyle(
                    context,
                    size: AppTextSize.s12,
                    weight: AppTextWeight.regular,
                    tone: AppTextTone.secondary,
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
