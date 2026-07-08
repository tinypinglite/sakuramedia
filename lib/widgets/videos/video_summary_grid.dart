import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:sakuramedia/features/videos/data/dto/video_item_list_item_dto.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/app_shell/app_empty_state.dart';
import 'package:sakuramedia/widgets/layout/staggered_layout.dart';
import 'package:sakuramedia/widgets/videos/video_summary_card.dart';

/// 视频卡片瀑布流：骨架屏 → 错误态 → 空态 → 卡片，按封面真实分辨率排版，
/// 横/竖封面混排时不留底色。封面宽高缺失（后端探测失败 / 无媒体）按 16:9 兜底。
///
/// 用 `MasonryGridView.count(shrinkWrap: true, physics: never)` 实现：外层 SingleChildScrollView
/// 提供滚动；MasonryGrid 自身懒构建（sliver-based），大列表内存与首屏开销可控。
class VideoSummaryGrid extends StatelessWidget {
  const VideoSummaryGrid({
    super.key,
    required this.items,
    required this.isLoading,
    this.errorMessage,
    this.onVideoTap,
    this.onVideoAddToCollection,
    this.onVideoDelete,
    this.selectionMode = false,
    this.selectedIds = const <int>{},
    this.onVideoToggleSelect,
    this.emptyMessage = '当前没有可展示的视频数据。',
    this.placeholderCount = 8,
  });

  final List<VideoItemListItemDto> items;
  final bool isLoading;
  final String? errorMessage;
  final ValueChanged<VideoItemListItemDto>? onVideoTap;
  final ValueChanged<VideoItemListItemDto>? onVideoAddToCollection;
  final ValueChanged<VideoItemListItemDto>? onVideoDelete;

  /// 选择模式：卡片切换为多选交互。
  final bool selectionMode;

  /// 已选视频 id 集合（仅 [selectionMode] 下有意义）。
  final Set<int> selectedIds;

  /// 选择模式下切换某个视频选中态的回调。
  final ValueChanged<VideoItemListItemDto>? onVideoToggleSelect;

  final String emptyMessage;
  final int placeholderCount;

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return _MasonryShell(
        gridKey: const Key('video-summary-grid-skeleton'),
        itemCount: placeholderCount,
        tileAspect: (_) => kStaggeredFallbackAspect,
        tileBuilder: (context, index) => _VideoSummaryCardSkeleton(
          key: Key('video-summary-card-skeleton-$index'),
        ),
      );
    }

    if (errorMessage != null) {
      return AppEmptyState(message: errorMessage!);
    }

    if (items.isEmpty) {
      return AppEmptyState(message: emptyMessage);
    }

    return _MasonryShell(
      gridKey: const Key('video-summary-grid'),
      itemCount: items.length,
      tileAspect: (i) => _resolveAspect(items[i].coverWidth, items[i].coverHeight),
      tileBuilder: (context, index) {
        final video = items[index];
        return VideoSummaryCard(
          video: video,
          // 整卡点击 = 弹窗快速播放；不可播放的视频不响应点击。
          onTap: (onVideoTap == null || !video.canPlay)
              ? null
              : () => onVideoTap!(video),
          onAddToCollection: onVideoAddToCollection == null
              ? null
              : () => onVideoAddToCollection!(video),
          onDelete: onVideoDelete == null ? null : () => onVideoDelete!(video),
          selectionMode: selectionMode,
          isSelected: selectedIds.contains(video.id),
          onSelectedChanged: onVideoToggleSelect == null
              ? null
              : (_) => onVideoToggleSelect!(video),
        );
      },
    );
  }
}

/// 主列表场景的瀑布流壳：外层是 `SingleChildScrollView`，本组件 `shrinkWrap: true` +
/// `NeverScrollableScrollPhysics` 让外层接管滚动；列数按当前宽与 `movieCardTargetWidth`
/// 自适应（与原 GridView 行为一致）。tile 用 `AspectRatio` 让 MasonryGrid 无须解码图
/// 就能算 tile 高度，懒构建照常生效。
class _MasonryShell extends StatelessWidget {
  const _MasonryShell({
    required this.gridKey,
    required this.itemCount,
    required this.tileAspect,
    required this.tileBuilder,
  });

  final Key gridKey;
  final int itemCount;
  final double Function(int index) tileAspect;
  final Widget Function(BuildContext context, int index) tileBuilder;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final spacing = context.appSpacing.md;
        final targetWidth = context.appComponentTokens.movieCardTargetWidth;
        final columns = _resolveColumnCount(
          width: constraints.maxWidth,
          spacing: spacing,
          targetWidth: targetWidth,
        );
        return MasonryGridView.count(
          key: gridKey,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: columns,
          mainAxisSpacing: spacing,
          crossAxisSpacing: spacing,
          itemCount: itemCount,
          itemBuilder: (context, index) {
            return AspectRatio(
              aspectRatio: tileAspect(index),
              child: tileBuilder(context, index),
            );
          },
        );
      },
    );
  }

  int _resolveColumnCount({
    required double width,
    required double spacing,
    required double targetWidth,
  }) {
    final columns = ((width + spacing) / (targetWidth + spacing)).floor();
    return math.max(2, math.min(6, columns));
  }
}

double _resolveAspect(int? width, int? height) {
  if (width != null && height != null && width > 0 && height > 0) {
    return width / height;
  }
  return kStaggeredFallbackAspect;
}

class _VideoSummaryCardSkeleton extends StatelessWidget {
  const _VideoSummaryCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: context.appColors.surfaceCard,
        borderRadius: context.appRadius.lgBorder,
        border: Border.all(color: context.appColors.borderSubtle),
        boxShadow: context.appShadows.card,
      ),
      clipBehavior: Clip.antiAlias,
      child: DecoratedBox(
        decoration: BoxDecoration(color: context.appColors.surfaceMuted),
      ),
    );
  }
}
