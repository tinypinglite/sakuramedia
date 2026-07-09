import 'package:flutter/material.dart';
import 'package:sakuramedia/features/image_search/data/image_search_result_item_dto.dart';
import 'package:sakuramedia/features/image_search/presentation/widgets/image_search_result_card.dart';
import 'package:sakuramedia/widgets/domain/media/preview/media_preview_dialog.dart';

class ImageSearchResultPreviewDialog extends StatelessWidget {
  const ImageSearchResultPreviewDialog({
    super.key,
    required this.item,
    this.presentation = MediaPreviewPresentation.dialog,
  });

  final ImageSearchResultItemDto item;
  final MediaPreviewPresentation presentation;

  @override
  Widget build(BuildContext context) {
    final imageUrl = item.image.resolvedUrl;
    final previewItem = MediaPreviewItem(
      imageUrl: imageUrl,
      fileName: 'image_search_${item.movieNumber}_${item.thumbnailId}.webp',
      mediaId: item.mediaId,
      movieNumber: item.movieNumber,
      thumbnailId: item.thumbnailId,
      offsetSeconds: item.offsetSeconds,
      scoreText: formatImageSearchScore(item.score),
    );

    return MediaPreviewDialog(
      item: previewItem,
      availableActions: <MediaPreviewAction>{
        if (imageUrl.isNotEmpty) MediaPreviewAction.searchSimilar,
        if (item.mediaId > 0) MediaPreviewAction.play,
        if (item.movieNumber.isNotEmpty) MediaPreviewAction.openMovieDetail,
      },
      presentation: presentation,
    );
  }
}
