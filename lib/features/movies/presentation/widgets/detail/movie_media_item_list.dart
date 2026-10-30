import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/core/format/file_size.dart';
import 'package:sakuramedia/core/format/media_timecode.dart';
import 'package:sakuramedia/features/movies/data/dto/detail/movie_detail_dto.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/actions/app_icon_button.dart';
import 'package:sakuramedia/features/movies/presentation/widgets/detail/movie_detail_pill_wrap.dart';
import 'package:sakuramedia/features/movies/presentation/widgets/detail/movie_media_point_gallery.dart';
import 'package:sakuramedia/l10n/app_localizations.dart';
import 'package:sakuramedia/widgets/base/layout/cards/app_badge.dart';

class MovieMediaItemList extends StatelessWidget {
  const MovieMediaItemList({
    super.key,
    required this.mediaItems,
    required this.selectedMediaId,
    required this.onSelect,
    this.isDeletingSelectedMedia = false,
    this.onDeleteSelectedMedia,
    this.onEditMediaTags,
    this.onOpenPointPreview,
    this.onRequestPointMenu,
  });

  final List<MovieMediaItemDto> mediaItems;
  final int? selectedMediaId;
  final ValueChanged<MovieMediaItemDto> onSelect;
  final bool isDeletingSelectedMedia;
  final ValueChanged<MovieMediaItemDto>? onDeleteSelectedMedia;
  final ValueChanged<MovieMediaItemDto>? onEditMediaTags;
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
    final contentGap = context.appComponentTokens.movieDetailSectionTitleGap;
    final selectedItem =
        mediaItems
            .where((item) => item.mediaId == selectedMediaId)
            .cast<MovieMediaItemDto?>()
            .firstWhere((item) => item != null, orElse: () => null) ??
        (mediaItems.isNotEmpty ? mediaItems.first : null);
    final technicalSummary = selectedItem == null
        ? null
        : _buildTechnicalSummary(selectedItem);
    final showDeleteAction =
        selectedItem != null && onDeleteSelectedMedia != null;
    final showTagAction = selectedItem != null && onEditMediaTags != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        MovieDetailPillWrap(
          emptyMessage: AppLocalizations.of(context).movieWidgetNoMediaSources,
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
        if (technicalSummary != null || showDeleteAction || showTagAction) ...[
          SizedBox(height: contentGap),
          Row(
            key: const Key('movie-media-summary-row'),
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Flexible(
                fit: FlexFit.loose,
                child: technicalSummary == null
                    ? const SizedBox(
                        key: Key('movie-media-tech-summary-placeholder'),
                      )
                    : Text(
                        technicalSummary,
                        key: const Key('movie-media-tech-summary'),
                        style: resolveAppTextStyle(
                          context,
                          size: AppTextSize.s12,
                          weight: AppTextWeight.regular,
                          tone: AppTextTone.muted,
                        ),
                      ),
              ),
              if (showTagAction) ...[
                SizedBox(width: context.appSpacing.sm),
                AppIconButton(
                  key: const Key('movie-media-tags-edit-button'),
                  icon: const Icon(Icons.sell_outlined),
                  tooltip: AppLocalizations.of(context).movieMediaTagsEdit,
                  semanticLabel: AppLocalizations.of(
                    context,
                  ).movieMediaTagsEdit,
                  size: AppIconButtonSize.mini,
                  onPressed: () => onEditMediaTags?.call(selectedItem),
                ),
              ],
              if (showDeleteAction) ...[
                SizedBox(width: context.appSpacing.md),
                AppIconButton(
                  key: const Key('movie-media-delete-button'),
                  icon: isDeletingSelectedMedia
                      ? SizedBox(
                          width: context.appComponentTokens.iconSizeSm,
                          height: context.appComponentTokens.iconSizeSm,
                          child: CircularProgressIndicator.adaptive(
                            backgroundColor: switch (Theme.of(
                              context,
                            ).platform) {
                              TargetPlatform.iOS || TargetPlatform.macOS =>
                                context.appTextPalette.error,
                              _ => null,
                            },
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              context.appTextPalette.error,
                            ),
                          ),
                        )
                      : const Icon(Icons.delete_outline_rounded),
                  tooltip: AppLocalizations.of(context).movieWidgetDeleteMedia,
                  semanticLabel: AppLocalizations.of(
                    context,
                  ).movieWidgetDeleteMedia,
                  size: AppIconButtonSize.mini,
                  iconColor: context.appTextPalette.error,
                  onPressed: isDeletingSelectedMedia
                      ? null
                      : () => onDeleteSelectedMedia?.call(selectedItem),
                ),
              ],
            ],
          ),
        ],
        if (selectedItem != null &&
            (selectedItem.tags.isNotEmpty ||
                selectedItem.isMediaTagsManuallyManaged)) ...[
          SizedBox(height: contentGap),
          Wrap(
            key: const Key('movie-media-tags'),
            spacing: context.appSpacing.sm,
            runSpacing: context.appSpacing.xs,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              if (selectedItem.isMediaTagsManuallyManaged)
                AppBadge(
                  key: const Key('movie-media-tags-manual-badge'),
                  label: AppLocalizations.of(context).mediaTagsAssignmentManualBadge,
                  tone: AppBadgeTone.primary,
                  size: AppBadgeSize.compact,
                ),
              for (final tag in selectedItem.tags)
                AppBadge(
                  key: Key('movie-media-tag-${selectedItem.mediaId}-${tag.id}'),
                  label: tag.name,
                  tone: AppBadgeTone.neutral,
                  size: AppBadgeSize.compact,
                ),
            ],
          ),
        ],
        if (selectedItem != null && selectedItem.points.isNotEmpty) ...[
          SizedBox(height: contentGap),
          Text(
            AppLocalizations.of(context).movieWidgetMomentsTitle,
            key: const Key('movie-media-points-title'),
            style: resolveAppTextStyle(
              context,
              size: AppTextSize.s14,
              weight: AppTextWeight.regular,
              tone: AppTextTone.secondary,
            ),
          ),
          SizedBox(
            height: context.appComponentTokens.movieDetailSectionTitleGap,
          ),
          MovieMediaPointGallery(
            points: selectedItem.points,
            onOpenPreview: onOpenPointPreview == null
                ? null
                : (point) => onOpenPointPreview!(selectedItem, point),
            onRequestPointMenu: onRequestPointMenu == null
                ? null
                : (menuContext, point, globalPosition) => onRequestPointMenu!(
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
    return formatFileSize(item.fileSizeBytes);
  }

  String? _buildTechnicalSummary(MovieMediaItemDto item) {
    final videoInfo = item.videoInfo;

    final parts = <String>[
      if (item.providerKey?.trim().isNotEmpty == true) item.providerKey!.trim(),
      if (item.fileName.trim().isNotEmpty) item.fileName.trim(),
      if (item.resolution?.trim().isNotEmpty == true) item.resolution!.trim(),
      if (item.durationSeconds > 0) formatMediaTimecode(item.durationSeconds),
      if (_formatVideoCodec(videoInfo?.video?.codecName) case final codec?)
        codec,
      if (_formatBitRate(
            videoInfo?.video?.bitRate,
            videoInfo?.container?.bitRate,
          )
          case final bitRate?)
        bitRate,
      if (_formatFrameRate(videoInfo?.video?.frameRate) case final frameRate?)
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
}
