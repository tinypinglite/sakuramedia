import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/features/videos/data/dto/video_item_list_item_dto.dart';
import 'package:sakuramedia/widgets/base/layout/grids/app_adaptive_card_grid.dart';
import 'package:sakuramedia/widgets/base/layout/grids/staggered_layout.dart';
import 'package:sakuramedia/features/videos/presentation/widgets/listing/video_summary_card.dart';

/// 视频卡片瀑布流：骨架屏 → 错误态 → 空态 → 卡片，按封面真实分辨率排版，
/// 横/竖封面混排时不留底色。封面宽高缺失（后端探测失败 / 无媒体）按 16:9 兜底。
///
/// 内部走 [AppAdaptiveCardGrid]（`layout: masonry`）:MasonryGridView 懒构建 +
/// 每 tile 从 item 的 `coverWidth/coverHeight` 算 aspect,大列表内存与首屏开销可控。
/// 累计分页视频列表使用的 Sliver 瀑布流版本。
class VideoSummarySliver extends StatelessWidget {
  const VideoSummarySliver({
    super.key,
    required this.items,
    this.errorMessage,
    this.onVideoTap,
    this.onVideoPlay,
    this.onVideoThumbnails,
    this.onVideoAddToCollection,
    this.onVideoDelete,
    this.selectionMode = false,
    this.selectedIds = const <int>{},
    this.onVideoToggleSelect,
    this.emptyMessage = '当前没有可展示的视频数据。',
  });

  final List<VideoItemListItemDto> items;
  final String? errorMessage;
  final ValueChanged<VideoItemListItemDto>? onVideoTap;

  /// 悬停面板播放键的回调；为 `null` 时卡片不显示播放键。
  final ValueChanged<VideoItemListItemDto>? onVideoPlay;

  /// 悬停面板「缩略图」动作；为 `null` 时卡片不显示。
  final ValueChanged<VideoItemListItemDto>? onVideoThumbnails;

  /// 悬停面板「加入合集」动作；为 `null` 时卡片不显示。
  final ValueChanged<VideoItemListItemDto>? onVideoAddToCollection;

  /// 悬停面板「删除」动作；为 `null` 时卡片不显示。
  final ValueChanged<VideoItemListItemDto>? onVideoDelete;

  final bool selectionMode;
  final Set<int> selectedIds;
  final ValueChanged<VideoItemListItemDto>? onVideoToggleSelect;
  final String emptyMessage;

  @override
  Widget build(BuildContext context) {
    return AppAdaptiveCardSliver<VideoItemListItemDto>(
      gridKey: const Key('video-summary-grid'),
      items: items,
      errorMessage: errorMessage,
      emptyMessage: emptyMessage,
      layout: AppAdaptiveCardGridLayout.masonry,
      tileAspect:
          (index) =>
              index < items.length
                  ? _resolveAspect(
                    items[index].coverWidth,
                    items[index].coverHeight,
                  )
                  : kStaggeredFallbackAspect,
      itemBuilder:
          (context, video, index) => VideoSummaryCard(
            video: video,
            onTap: onVideoTap == null ? null : () => onVideoTap!(video),
            onPlay: onVideoPlay == null ? null : () => onVideoPlay!(video),
            onThumbnails: onVideoThumbnails == null
                ? null
                : () => onVideoThumbnails!(video),
            onAddToCollection: onVideoAddToCollection == null
                ? null
                : () => onVideoAddToCollection!(video),
            onDelete: onVideoDelete == null
                ? null
                : () => onVideoDelete!(video),
            selectionMode: selectionMode,
            isSelected: selectedIds.contains(video.id),
            onSelectedChanged:
                onVideoToggleSelect == null
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
