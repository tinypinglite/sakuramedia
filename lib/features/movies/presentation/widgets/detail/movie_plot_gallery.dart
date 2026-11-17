import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/features/movies/data/dto/listing/movie_list_item_dto.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/interaction/app_clickable.dart';
import 'package:sakuramedia/widgets/base/media/images/app_image_action_trigger.dart';
import 'package:sakuramedia/features/movies/presentation/widgets/detail/movie_detail_empty_panel.dart';
import 'package:sakuramedia/features/movies/presentation/widgets/detail/movie_plot_thumbnail.dart';
import 'package:sakuramedia/l10n/app_localizations.dart';

class MoviePlotGallery extends StatelessWidget {
  const MoviePlotGallery({
    super.key,
    required this.plotImages,
    this.onOpenPreview,
    this.onRequestImageMenu,
  });

  final List<MovieImageDto> plotImages;
  final ValueChanged<int>? onOpenPreview;
  final Future<void> Function(
    BuildContext context,
    int index,
    Offset globalPosition,
  )?
  onRequestImageMenu;

  @override
  Widget build(BuildContext context) {
    if (plotImages.isEmpty) {
      return MovieDetailEmptyPanel(
        message: AppLocalizations.of(context).movieWidgetNoPlotImages,
      );
    }

    final spacing = context.appSpacing;
    final tokens = context.appComponentTokens;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: List<Widget>.generate(plotImages.length, (index) {
          final image = plotImages[index];
          final thumbnail = MoviePlotThumbnail(
            maxHeight: tokens.movieDetailPlotThumbnailHeight,
            fallbackAspectRatio:
                tokens.movieDetailPlotThumbnailWidth /
                tokens.movieDetailPlotThumbnailHeight,
            borderRadius: context.appRadius.mdBorder,
            url: image.origin,
          );

          final gestureChild = onRequestImageMenu == null
              ? AppClickable(
                  key: Key('movie-plot-thumb-$index'),
                  enabled: onOpenPreview != null,
                  onTap: onOpenPreview == null
                      ? null
                      : () => onOpenPreview!(index),
                  child: thumbnail,
                )
              : AppImageActionTrigger(
                  key: Key('movie-plot-thumb-$index'),
                  onTap: onOpenPreview == null
                      ? null
                      : () => onOpenPreview!(index),
                  onRequestMenu: (globalPosition) =>
                      onRequestImageMenu!(context, index, globalPosition),
                  child: thumbnail,
                );

          return Padding(
            padding: EdgeInsets.only(
              right: index == plotImages.length - 1 ? 0 : spacing.sm,
            ),
            child: gestureChild,
          );
        }),
      ),
    );
  }
}
