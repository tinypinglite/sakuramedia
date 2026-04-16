import 'package:flutter/material.dart';
import 'package:sakuramedia/core/format/media_timecode.dart';
import 'package:sakuramedia/features/movies/data/movie_detail_dto.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/media/app_image_action_trigger.dart';
import 'package:sakuramedia/widgets/movie_detail/movie_plot_thumbnail.dart';

class MovieMediaPointGallery extends StatelessWidget {
  const MovieMediaPointGallery({
    super.key,
    required this.points,
    this.onOpenPreview,
    this.onRequestPointMenu,
    this.emptyMessage = '暂无标记点',
  });

  final List<MovieMediaPointDto> points;
  final ValueChanged<MovieMediaPointDto>? onOpenPreview;
  final Future<void> Function(
    BuildContext context,
    MovieMediaPointDto point,
    Offset globalPosition,
  )?
  onRequestPointMenu;
  final String emptyMessage;

  @override
  Widget build(BuildContext context) {
    if (points.isEmpty) {
      return _EmptyPanel(message: emptyMessage);
    }

    final spacing = context.appSpacing;
    final tokens = context.appComponentTokens;

    return SingleChildScrollView(
      key: const Key('movie-media-point-gallery'),
      scrollDirection: Axis.horizontal,
      child: Row(
        children: List<Widget>.generate(points.length, (index) {
          final point = points[index];
          final thumbnail = Stack(
            children: [
              MoviePlotThumbnail(
                maxHeight: tokens.movieDetailPlotThumbnailHeight,
                fallbackAspectRatio:
                    tokens.movieDetailPlotThumbnailWidth /
                    tokens.movieDetailPlotThumbnailHeight,
                borderRadius: context.appRadius.mdBorder,
                url: point.image?.bestAvailableUrl ?? '',
              ),
              Positioned(
                right: spacing.xs,
                bottom: spacing.xs,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.72),
                    borderRadius: context.appRadius.smBorder,
                  ),
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: spacing.xs,
                      vertical: spacing.xs / 2,
                    ),
                    child: Text(
                      formatMediaTimecode(point.offsetSeconds),
                      key: Key('movie-media-point-timecode-$index'),
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );

          final gestureChild =
              onRequestPointMenu == null
                  ? GestureDetector(
                    key: Key('movie-media-point-thumb-$index'),
                    onTap:
                        onOpenPreview == null
                            ? null
                            : () => onOpenPreview!(point),
                    child: thumbnail,
                  )
                  : AppImageActionTrigger(
                    key: Key('movie-media-point-thumb-$index'),
                    onTap:
                        onOpenPreview == null
                            ? null
                            : () => onOpenPreview!(point),
                    onRequestMenu:
                        (globalPosition) =>
                            onRequestPointMenu!(context, point, globalPosition),
                    child: thumbnail,
                  );

          return Padding(
            padding: EdgeInsets.only(
              right: index == points.length - 1 ? 0 : spacing.sm,
            ),
            child: gestureChild,
          );
        }),
      ),
    );
  }
}

class _EmptyPanel extends StatelessWidget {
  const _EmptyPanel({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('movie-media-point-empty'),
      width: double.infinity,
      padding: EdgeInsets.all(context.appSpacing.lg),
      decoration: BoxDecoration(
        color: context.appColors.movieDetailEmptyBackground,
        borderRadius: context.appRadius.mdBorder,
      ),
      child: Text(
        message,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: context.appColors.textSecondary,
        ),
      ),
    );
  }
}
