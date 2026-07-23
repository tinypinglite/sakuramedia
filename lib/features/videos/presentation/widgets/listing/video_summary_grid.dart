import 'package:flutter/material.dart';
import 'package:sakuramedia/features/videos/data/dto/video_item_list_item_dto.dart';
import 'package:sakuramedia/widgets/base/feedback/app_cover_card_skeleton.dart';
import 'package:sakuramedia/widgets/base/layout/grids/app_adaptive_card_grid.dart';
import 'package:sakuramedia/widgets/base/layout/grids/staggered_layout.dart';
import 'package:sakuramedia/features/videos/presentation/widgets/listing/video_summary_card.dart';

/// 视频卡片瀑布流：骨架屏 → 错误态 → 空态 → 卡片，按封面真实分辨率排版，
/// 横/竖封面混排时不留底色。封面宽高缺失（后端探测失败 / 无媒体）按 16:9 兜底。
///
/// 内部走 [AppAdaptiveCardGrid]（`layout: masonry`）:MasonryGridView 懒构建 +
/// 每 tile 从 item 的 `coverWidth/coverHeight` 算 aspect,大列表内存与首屏开销可控。
class VideoSummaryGrid extends StatelessWidget {
  const VideoSummaryGrid({
    super.key,
    required this.items,
    required this.isLoading,
    this.errorMessage,
    this.onVideoTap,
    this.selectionMode = false,
    this.selectedIds = const <int>{},
    this.onVideoToggleSelect,
    this.emptyMessage = '当前没有可展示的视频数据。',
    this.placeholderCount = 8,
  });

  final List<VideoItemListItemDto> items;
  final bool isLoading;
  final String? errorMessage;

  /// 卡片点击 → 桌面走动作弹窗、移动走 sheet；两端弹窗承载播放/加入合集/删除。
  final ValueChanged<VideoItemListItemDto>? onVideoTap;

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
    return AppAdaptiveCardGrid<VideoItemListItemDto>(
      gridKey: isLoading
          ? const Key('video-summary-grid-skeleton')
          : const Key('video-summary-grid'),
      items: items,
      isLoading: isLoading,
      errorMessage: errorMessage,
      emptyMessage: emptyMessage,
      placeholderCount: placeholderCount,
      layout: AppAdaptiveCardGridLayout.masonry,
      tileAspect: (index) => index < items.length
          ? _resolveAspect(items[index].coverWidth, items[index].coverHeight)
          : kStaggeredFallbackAspect,
      skeletonBuilder: (context, index) => AppCoverCardSkeleton(
        key: Key('video-summary-card-skeleton-$index'),
      ),
      itemBuilder: (context, video, index) => VideoSummaryCard(
        video: video,
        onTap: onVideoTap == null ? null : () => onVideoTap!(video),
        selectionMode: selectionMode,
        isSelected: selectedIds.contains(video.id),
        onSelectedChanged: onVideoToggleSelect == null
            ? null
            : (_) => onVideoToggleSelect!(video),
      ),
    );
  }
}

/// 累计分页视频列表使用的 Sliver 瀑布流版本。
class VideoSummarySliver extends StatelessWidget {
  const VideoSummarySliver({
    super.key,
    required this.items,
    required this.isLoading,
    this.errorMessage,
    this.onVideoTap,
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
  final bool selectionMode;
  final Set<int> selectedIds;
  final ValueChanged<VideoItemListItemDto>? onVideoToggleSelect;
  final String emptyMessage;
  final int placeholderCount;

  @override
  Widget build(BuildContext context) {
    return AppAdaptiveCardSliver<VideoItemListItemDto>(
      gridKey: isLoading
          ? const Key('video-summary-grid-skeleton')
          : const Key('video-summary-grid'),
      items: items,
      isLoading: isLoading,
      errorMessage: errorMessage,
      emptyMessage: emptyMessage,
      placeholderCount: placeholderCount,
      layout: AppAdaptiveCardGridLayout.masonry,
      tileAspect: (index) => index < items.length
          ? _resolveAspect(items[index].coverWidth, items[index].coverHeight)
          : kStaggeredFallbackAspect,
      skeletonBuilder: (context, index) => AppCoverCardSkeleton(
        key: Key('video-summary-card-skeleton-$index'),
      ),
      itemBuilder: (context, video, index) => VideoSummaryCard(
        video: video,
        onTap: onVideoTap == null ? null : () => onVideoTap!(video),
        selectionMode: selectionMode,
        isSelected: selectedIds.contains(video.id),
        onSelectedChanged: onVideoToggleSelect == null
            ? null
            : (_) => onVideoToggleSelect!(video),
      ),
    );
  }
}

double _resolveAspect(int? width, int? height) {
  if (width != null && height != null && width > 0 && height > 0) {
    return width / height;
  }
  return kStaggeredFallbackAspect;
}
