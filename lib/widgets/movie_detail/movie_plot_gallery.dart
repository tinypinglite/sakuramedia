import 'package:flutter/material.dart';
import 'package:sakuramedia/features/movies/data/movie_list_item_dto.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/media/app_image_action_trigger.dart';
import 'package:sakuramedia/widgets/movie_detail/movie_plot_thumbnail.dart';

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
      return _EmptyPanel(message: '暂无剧情图');
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
            url: image.bestAvailableUrl,
          );

          final gestureChild =
              onRequestImageMenu == null
                  ? GestureDetector(
                    key: Key('movie-plot-thumb-$index'),
                    onTap:
                        onOpenPreview == null
                            ? null
                            : () => onOpenPreview!(index),
                    child: thumbnail,
                  )
                  : AppImageActionTrigger(
                    key: Key('movie-plot-thumb-$index'),
                    onTap:
                        onOpenPreview == null
                            ? null
                            : () => onOpenPreview!(index),
                    onRequestMenu:
                        (globalPosition) =>
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

class _EmptyPanel extends StatelessWidget {
  const _EmptyPanel({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
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
