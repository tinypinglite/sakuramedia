import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/features/videos/data/dto/video_item_list_item_dto.dart';
import 'package:sakuramedia/features/videos/presentation/video_placeholders.dart';
import 'package:sakuramedia/features/videos/presentation/widgets/listing/video_summary_card.dart';
import 'package:sakuramedia/l10n/app_localizations.dart';
import 'package:sakuramedia/widgets/base/feedback/app_skeletonizer.dart';
import 'package:sakuramedia/widgets/base/layout/grids/app_adaptive_card_grid.dart';
import 'package:sakuramedia/widgets/base/layout/grids/staggered_layout.dart';

/// PornBox 视频瀑布流：双端共用网格、空态、错误态和封面比例计算。
class VideoOverviewGridSliver extends StatelessWidget {
  const VideoOverviewGridSliver({
    super.key,
    required this.gridKey,
    required this.videos,
    required this.isLoading,
    this.errorMessage,
    this.emptyMessage,
    this.placeholderCount = 8,
    this.onVideoTap,
    this.onVideoPlay,
    this.onVideoThumbnails,
    this.onVideoAddToCollection,
    this.onVideoDelete,
    this.selectionMode = false,
    this.selectedIds = const <int>{},
    this.onVideoToggleSelect,
    this.wrapCard,
  });

  final Key gridKey;
  final List<VideoItemListItemDto> videos;
  final bool isLoading;
  final String? errorMessage;
  final String? emptyMessage;
  final int placeholderCount;
  final ValueChanged<VideoItemListItemDto>? onVideoTap;
  final ValueChanged<VideoItemListItemDto>? onVideoPlay;
  final ValueChanged<VideoItemListItemDto>? onVideoThumbnails;
  final ValueChanged<VideoItemListItemDto>? onVideoAddToCollection;
  final ValueChanged<VideoItemListItemDto>? onVideoDelete;
  final bool selectionMode;
  final Set<int> selectedIds;
  final ValueChanged<VideoItemListItemDto>? onVideoToggleSelect;

  /// 移动端用它给卡片套上下文菜单；桌面端不传。
  final Widget Function(
    BuildContext context,
    VideoItemListItemDto video,
    Widget card,
  )?
  wrapCard;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final items = isLoading
        ? videoSummaryPlaceholders(count: placeholderCount)
        : videos;
    return AppSkeletonizer.sliver(
      enabled: isLoading,
      child: AppAdaptiveCardSliver<VideoItemListItemDto>(
        gridKey: gridKey,
        items: items,
        errorMessage: errorMessage,
        emptyMessage: emptyMessage ?? l10n.videoEmptyList,
        layout: AppAdaptiveCardGridLayout.masonry,
        tileAspect: (index) =>
            _resolveAspect(items[index].coverWidth, items[index].coverHeight),
        itemBuilder: (context, video, index) {
          final card = VideoSummaryCard(
            video: video,
            onTap: selectionMode
                ? null
                : (onVideoTap == null ? null : () => onVideoTap!(video)),
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
            onSelectedChanged: onVideoToggleSelect == null
                ? null
                : (_) => onVideoToggleSelect!(video),
          );
          return wrapCard?.call(context, video, card) ?? card;
        },
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
