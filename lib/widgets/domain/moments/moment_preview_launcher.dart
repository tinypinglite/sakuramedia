import 'package:flutter/material.dart';
import 'package:sakuramedia/features/moments/presentation/moment_listing_models.dart';
import 'package:sakuramedia/widgets/domain/media/preview/media_preview_dialog.dart';
import 'package:sakuramedia/widgets/domain/moments/moment_image.dart';

Future<MediaPreviewAction?> showMomentPreviewOverlay({
  required BuildContext context,
  required MomentListItem item,
  required MediaPreviewPresentation presentation,
  Key? drawerKey,
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
    presentation: presentation,
    drawerKey: drawerKey,
    builder: (_) => MediaPreviewDialog(
      item: MediaPreviewItem(
        imageUrl: imageUrl,
        fileName: buildMomentImageFileName(item, imageUrl),
        mediaId: item.mediaId,
        movieNumber: item.movieNumber,
        videoItemId: item.videoItemId,
        thumbnailId: item.thumbnailId,
        offsetSeconds: item.offsetSeconds,
      ),
      availableActions: <MediaPreviewAction>{
        if (imageUrl.isNotEmpty) MediaPreviewAction.searchSimilar,
        if (allowAddToCollection && item.mediaId > 0 && item.thumbnailId > 0)
          MediaPreviewAction.addToCollection,
        if (item.mediaId > 0) MediaPreviewAction.play,
        if (!item.isVideo && movieNumber != null && movieNumber.isNotEmpty)
          MediaPreviewAction.openMovieDetail,
      },
      onPointRemoved: onPointRemoved,
      closeOnPointRemoved: closeOnPointRemoved,
      presentation: presentation,
      useInlineNavigation: useInlineNavigation,
      onActorSelected: onActorSelected,
    ),
  );
}
