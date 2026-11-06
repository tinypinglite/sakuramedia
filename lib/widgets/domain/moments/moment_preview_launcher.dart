import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/features/moments/presentation/moment_listing_models.dart';
import 'package:sakuramedia/widgets/base/overlays/app_adaptive_modal.dart';
import 'package:sakuramedia/widgets/domain/media/preview/media_preview_dialog.dart';
import 'package:sakuramedia/widgets/domain/moments/moment_image.dart';

Future<MediaPreviewAction?> showMomentPreviewOverlay({
  required BuildContext context,
  required MomentListItem item,
  required AppAdaptiveModalVariant variant,
  Key? drawerKey,
  // 仅传真实收藏 ID；推荐条目的 item.pointId 是推荐 ID。
  int? pointId,
  VoidCallback? onPointRemoved,
  bool closeOnPointRemoved = false,
  bool allowAddToCollection = false,
  bool useInlineNavigation = false,
  ValueChanged<int>? onActorSelected,
}) {
  final imageUrl = resolveMomentImageUrl(item);
  final movieNumber = item.movieNumber;
  return showMediaPreviewOverlay(
    context: context,
    variant: variant,
    drawerKey: drawerKey,
    builder: (_) => MediaPreviewDialog(
      item: MediaPreviewItem(
        imageUrl: imageUrl,
        pointId: pointId,
        fileName: buildMomentImageFileName(item, imageUrl),
        mediaId: item.mediaId,
        movieNumber: item.movieNumber,
        videoItemId: item.videoItemId,
        thumbnailId: item.thumbnailId,
        offsetSeconds: item.offsetSeconds,
      ),
      availableActions: <MediaPreviewAction>{
        if (imageUrl.isNotEmpty) MediaPreviewAction.searchSimilar,
        if (allowAddToCollection &&
            (pointId != null || (item.mediaId > 0 && item.thumbnailId > 0)))
          MediaPreviewAction.addToCollection,
        if (item.mediaId > 0) MediaPreviewAction.play,
        if (!item.isVideo && movieNumber != null && movieNumber.isNotEmpty)
          MediaPreviewAction.openMovieDetail,
      },
      onPointRemoved: onPointRemoved,
      closeOnPointRemoved: closeOnPointRemoved,
      useInlineNavigation: useInlineNavigation,
      onActorSelected: onActorSelected,
    ),
  );
}
