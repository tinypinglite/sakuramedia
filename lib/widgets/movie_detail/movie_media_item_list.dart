import 'package:flutter/material.dart';
import 'package:sakuramedia/features/movies/data/movie_detail_dto.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/movie_detail/movie_detail_pill_wrap.dart';
import 'package:sakuramedia/widgets/movie_detail/movie_media_point_gallery.dart';

class MovieMediaItemList extends StatelessWidget {
  const MovieMediaItemList({
    super.key,
    required this.mediaItems,
    required this.selectedMediaId,
    required this.onSelect,
    this.onOpenPointPreview,
    this.onRequestPointMenu,
  });

  final List<MovieMediaItemDto> mediaItems;
  final int? selectedMediaId;
  final ValueChanged<MovieMediaItemDto> onSelect;
  final void Function(MovieMediaItemDto mediaItem, MovieMediaPointDto point)?
  onOpenPointPreview;
  final Future<void> Function(
    BuildContext context,
    MovieMediaItemDto mediaItem,
    MovieMediaPointDto point,
    Offset globalPosition,
  )?
  onRequestPointMenu;

  @override
  Widget build(BuildContext context) {
    final selectedItem =
        mediaItems
            .where((item) => item.mediaId == selectedMediaId)
            .cast<MovieMediaItemDto?>()
            .firstWhere((item) => item != null, orElse: () => null) ??
        (mediaItems.isNotEmpty ? mediaItems.first : null);
    final technicalSummary =
        selectedItem == null ? null : _buildTechnicalSummary(selectedItem);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        MovieDetailPillWrap(
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
        ),
        if (technicalSummary != null) ...[
          SizedBox(height: context.appSpacing.sm),
          Text(
            technicalSummary,
            key: const Key('movie-media-tech-summary'),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: context.appColors.textMuted),
          ),
        ],
        if (selectedItem != null && selectedItem.points.isNotEmpty) ...[
          SizedBox(height: context.appSpacing.sm),
          MovieMediaPointGallery(
            points: selectedItem.points,
            onOpenPreview:
                onOpenPointPreview == null
                    ? null
                    : (point) => onOpenPointPreview!(selectedItem, point),
            onRequestPointMenu:
                onRequestPointMenu == null
                    ? null
                    : (menuContext, point, globalPosition) =>
                        onRequestPointMenu!(
                          menuContext,
                          selectedItem,
                          point,
                          globalPosition,
                        ),
          ),
        ],
      ],
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

  String? _buildTechnicalSummary(MovieMediaItemDto item) {
    final videoInfo = item.videoInfo;
    if (videoInfo == null) {
      return null;
    }

    final parts = <String>[
      if (_formatVideoCodec(videoInfo.video?.codecName) case final codec?)
        codec,
      if (_formatBitRate(videoInfo.video?.bitRate, videoInfo.container?.bitRate)
          case final bitRate?)
        bitRate,
      if (_formatFrameRate(videoInfo.video?.frameRate) case final frameRate?)
        frameRate,
    ];

    if (parts.isEmpty) {
      return null;
    }
    return parts.join(' · ');
  }

  String? _formatVideoCodec(String? codecName) {
    final normalized = codecName?.trim().toLowerCase();
    if (normalized == null || normalized.isEmpty) {
      return null;
    }
    switch (normalized) {
      case 'h264':
      case 'avc':
        return 'H.264';
      case 'h265':
      case 'hevc':
        return 'H.265';
      default:
        return normalized.replaceAll('_', '-').toUpperCase();
    }
  }

  String? _formatBitRate(int? videoBitRate, int? containerBitRate) {
    final bitRate = videoBitRate ?? containerBitRate;
    if (bitRate == null || bitRate <= 0) {
      return null;
    }
    return '${(bitRate / 1000000).toStringAsFixed(1)} Mbps';
  }

  String? _formatFrameRate(double? frameRate) {
    if (frameRate == null || frameRate <= 0) {
      return null;
    }
    if ((frameRate - frameRate.roundToDouble()).abs() < 0.001) {
      return '${frameRate.round()} fps';
    }
    final formatted = frameRate
        .toStringAsFixed(2)
        .replaceFirst(RegExp(r'0+$'), '')
        .replaceFirst(RegExp(r'\.$'), '');
    return '$formatted fps';
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
