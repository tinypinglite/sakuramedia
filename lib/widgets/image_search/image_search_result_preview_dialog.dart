import 'package:flutter/material.dart';
import 'package:sakuramedia/features/image_search/data/image_search_result_item_dto.dart';
import 'package:sakuramedia/widgets/image_search/image_search_result_card.dart';
import 'package:sakuramedia/widgets/media/media_preview_dialog.dart';

class ImageSearchResultPreviewDialog extends StatelessWidget {
  const ImageSearchResultPreviewDialog({
    super.key,
    required this.item,
    required this.onSearchSimilar,
    required this.onPlay,
    required this.onOpenMovieDetail,
    this.presentation = MediaPreviewPresentation.dialog,
  });

  final ImageSearchResultItemDto item;
  final Future<bool> Function() onSearchSimilar;
  final VoidCallback onPlay;
  final VoidCallback onOpenMovieDetail;
  final MediaPreviewPresentation presentation;

  @override
  Widget build(BuildContext context) {
    final imageUrl =
        item.image.origin.trim().isNotEmpty
            ? item.image.origin.trim()
            : item.image.bestAvailableUrl;
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
      onSearchSimilar: onSearchSimilar,
      onPlay: onPlay,
      onOpenMovieDetail: onOpenMovieDetail,
      presentation: presentation,
    );
  }
}
