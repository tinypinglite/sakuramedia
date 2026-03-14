import 'package:flutter/material.dart';
import 'package:sakuramedia/features/movies/data/movie_detail_dto.dart';
import 'package:sakuramedia/widgets/movie_detail/movie_detail_pill_wrap.dart';

class MovieMediaItemList extends StatelessWidget {
  const MovieMediaItemList({
    super.key,
    required this.mediaItems,
    required this.selectedMediaId,
    required this.onSelect,
  });

  final List<MovieMediaItemDto> mediaItems;
  final int? selectedMediaId;
  final ValueChanged<MovieMediaItemDto> onSelect;

  @override
  Widget build(BuildContext context) {
    return MovieDetailPillWrap(
      emptyMessage: '暂无媒体源',
      items: mediaItems
          .map((item) {
            final isSelected = item.mediaId == selectedMediaId;
            return MovieDetailPillItem(
              label: _buildLabel(item),
              isSelected: isSelected,
              onTap: () => onSelect(item),
            );
          })
          .toList(growable: false),
    );
  }

  String _buildLabel(MovieMediaItemDto item) {
    final parts = <String>[
      if (item.specialTags.trim().isNotEmpty) item.specialTags.trim(),
      _formatFileSize(item.fileSizeBytes),
    ];
    if (parts.isNotEmpty) {
      return parts.join(' ');
    }
    if (item.resolution.isNotEmpty) {
      return item.resolution;
    }
    return '媒体源 ${item.mediaId}';
  }

  String _formatFileSize(int bytes) {
    if (bytes <= 0) {
      return '0 MB';
    }
    const bytesPerGb = 1024 * 1024 * 1024;
    const bytesPerMb = 1024 * 1024;
    if (bytes >= bytesPerGb) {
      return '${(bytes / bytesPerGb).toStringAsFixed(1)} GB';
    }
    return '${(bytes / bytesPerMb).toStringAsFixed(1)} MB';
  }
}
