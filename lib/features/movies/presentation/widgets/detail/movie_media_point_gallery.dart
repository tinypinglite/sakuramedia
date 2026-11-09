import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/core/format/media_timecode.dart';
import 'package:sakuramedia/features/movies/data/dto/detail/movie_detail_dto.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/interaction/app_clickable.dart';
import 'package:sakuramedia/widgets/base/media/images/app_image_action_trigger.dart';
import 'package:sakuramedia/features/movies/presentation/widgets/detail/movie_detail_empty_panel.dart';
import 'package:sakuramedia/features/movies/presentation/widgets/detail/movie_plot_thumbnail.dart';
import 'package:sakuramedia/l10n/app_localizations.dart';

class MovieMediaPointGallery extends StatelessWidget {
  const MovieMediaPointGallery({
    super.key,
    required this.points,
    this.onOpenPreview,
    this.onRequestPointMenu,
    this.emptyMessage,
  });

  final List<MovieMediaPointDto> points;
  final ValueChanged<MovieMediaPointDto>? onOpenPreview;
  final Future<void> Function(
    BuildContext context,
    MovieMediaPointDto point,
    Offset globalPosition,
  )?
  onRequestPointMenu;

  /// 空态文案；为 null 时用当前语言的默认文案。
  final String? emptyMessage;

  @override
  Widget build(BuildContext context) {
    if (points.isEmpty) {
      return MovieDetailEmptyPanel(
        key: const Key('movie-media-point-empty'),
        message:
            emptyMessage ??
            AppLocalizations.of(context).movieWidgetNoMediaPoints,
      );
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
                url: point.image?.origin ?? '',
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
                      style: resolveAppTextStyle(
                        context,
                        size: AppTextSize.s12,
                        weight: AppTextWeight.regular,
                        tone: AppTextTone.onMedia,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );

          final gestureChild = onRequestPointMenu == null
              ? AppClickable(
                  key: Key('movie-media-point-thumb-$index'),
                  enabled: onOpenPreview != null,
                  onTap: onOpenPreview == null
                      ? null
                      : () => onOpenPreview!(point),
                  child: thumbnail,
                )
              : AppImageActionTrigger(
                  key: Key('movie-media-point-thumb-$index'),
                  onTap: onOpenPreview == null
                      ? null
                      : () => onOpenPreview!(point),
                  onRequestMenu: (globalPosition) =>
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
