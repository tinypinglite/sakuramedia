import 'package:flutter/material.dart';
import 'package:sakuramedia/features/moments/presentation/paged_moment_controller.dart';
import 'package:sakuramedia/widgets/domain/media/preview/media_preview_dialog.dart';
import 'package:sakuramedia/widgets/domain/moments/moment_image.dart';

class MomentPreviewDialog extends StatelessWidget {
  const MomentPreviewDialog({
    super.key,
    required this.item,
    this.onPointRemoved,
    this.closeOnPointRemoved = false,
    this.presentation = MediaPreviewPresentation.dialog,
  });

  final MomentListItem item;
  final VoidCallback? onPointRemoved;
  final bool closeOnPointRemoved;
  final MediaPreviewPresentation presentation;

  @override
  Widget build(BuildContext context) {
    final imageUrl = resolveMomentImageUrl(item);
    final previewItem = MediaPreviewItem(
      imageUrl: imageUrl,
      fileName: buildMomentImageFileName(item, imageUrl),
      mediaId: item.mediaId,
      movieNumber: item.movieNumber,
      videoItemId: item.videoItemId,
      thumbnailId: item.thumbnailId,
      offsetSeconds: item.offsetSeconds,
    );
    final movieNumber = item.movieNumber;

    return MediaPreviewDialog(
      item: previewItem,
      availableActions: <MediaPreviewAction>{
        if (imageUrl.isNotEmpty) MediaPreviewAction.searchSimilar,
        if (item.mediaId > 0) MediaPreviewAction.play,
        if (!item.isVideo && movieNumber != null && movieNumber.isNotEmpty)
          MediaPreviewAction.openMovieDetail,
      },
      onPointRemoved: onPointRemoved,
      closeOnPointRemoved: closeOnPointRemoved,
      presentation: presentation,
    );
  }
}
