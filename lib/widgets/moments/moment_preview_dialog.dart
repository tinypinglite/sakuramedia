import 'package:flutter/material.dart';
import 'package:sakuramedia/features/image_search/presentation/image_search_file_picker.dart';
import 'package:sakuramedia/features/moments/presentation/paged_moment_controller.dart';
import 'package:sakuramedia/widgets/media/media_preview_dialog.dart';

class MomentPreviewDialog extends StatelessWidget {
  const MomentPreviewDialog({
    super.key,
    required this.item,
    this.onSearchSimilar,
    this.onPlay,
    this.onOpenMovieDetail,
    this.onPointRemoved,
    this.closeOnPointRemoved = false,
    this.presentation = MediaPreviewPresentation.dialog,
  });

  final MomentListItem item;
  final Future<bool> Function()? onSearchSimilar;
  final VoidCallback? onPlay;
  final VoidCallback? onOpenMovieDetail;
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
      offsetSeconds: item.offsetSeconds,
    );

    return MediaPreviewDialog(
      item: previewItem,
      onSearchSimilar: onSearchSimilar,
      onPlay: onPlay,
      onOpenMovieDetail: onOpenMovieDetail,
      onPointRemoved: onPointRemoved,
      closeOnPointRemoved: closeOnPointRemoved,
      presentation: presentation,
    );
  }
}

String resolveMomentImageUrl(MomentListItem item) {
  final image = item.image;
  if (image == null) {
    return '';
  }
  final origin = image.origin.trim();
  if (origin.isNotEmpty) {
    return origin;
  }
  return image.bestAvailableUrl;
}

String buildMomentImageFileName(MomentListItem item, String imageUrl) {
  final extension = guessImageFileExtension(imageUrl, fallback: 'webp');
  return 'moment_${item.movieNumber}_${item.pointId}.$extension';
}
