import 'package:flutter/material.dart';
import 'package:sakuramedia/core/format/image_file_extension.dart';
import 'package:sakuramedia/features/image_search/data/image_search_result_item_dto.dart';
import 'package:sakuramedia/features/image_search/presentation/widgets/image_search_result_card.dart';
import 'package:sakuramedia/widgets/domain/media/preview/media_preview_dialog.dart';

/// 图搜结果到通用媒体预览的字段映射。
class ImageSearchResultPreviewDialog extends StatelessWidget {
  const ImageSearchResultPreviewDialog({
    super.key,
    required this.item,
    this.presentation = MediaPreviewPresentation.dialog,
    this.onActorSelected,
  });

  final ImageSearchResultItemDto item;
  final MediaPreviewPresentation presentation;
  final ValueChanged<int>? onActorSelected;

  @override
  Widget build(BuildContext context) {
    final origin = item.image.origin.trim();
    final imageUrl = origin.isNotEmpty ? origin : item.image.bestAvailableUrl;
    final extension = guessImageFileExtension(imageUrl);
    return MediaPreviewDialog(
      item: MediaPreviewItem(
        imageUrl: imageUrl,
        fileName:
            'image_search_${item.movieNumber}_${item.resultImageId}.$extension',
        mediaId: item.mediaId,
        movieNumber: item.movieNumber,
        thumbnailId: item.thumbnailId,
        offsetSeconds: item.offsetSeconds,
        scoreText: formatImageSearchScore(item.score),
      ),
      availableActions: <MediaPreviewAction>{
        if (imageUrl.isNotEmpty) MediaPreviewAction.searchSimilar,
        if (item.mediaId > 0 && item.thumbnailId > 0)
          MediaPreviewAction.addToCollection,
        if (item.mediaId > 0) MediaPreviewAction.play,
        if (item.movieNumber.isNotEmpty) MediaPreviewAction.openMovieDetail,
      },
      presentation: presentation,
      useInlineNavigation: true,
      onActorSelected: onActorSelected,
    );
  }
}
