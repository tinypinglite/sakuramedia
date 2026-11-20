import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/features/movies/data/dto/listing/movie_list_item_dto.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/tv/tv_movie_card.dart';

class TvMovieGrid extends StatelessWidget {
  const TvMovieGrid({
    super.key,
    required this.items,
    required this.onPressed,
    this.controller,
  });

  final List<MovieListItemDto> items;
  final void Function(MovieListItemDto movie) onPressed;
  final ScrollController? controller;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = AppTvTokens.gridColumnsForWidth(constraints.maxWidth);
        final availableWidth =
            constraints.maxWidth - AppTvTokens.gridGap * (columns - 1);
        final cardWidth = availableWidth / columns;
        final cardHeight =
            cardWidth / (AppTvTokens.posterWidth / AppTvTokens.posterHeight);
        return GridView.builder(
          key: const Key('tv-movie-grid'),
          controller: controller,
          padding: const EdgeInsets.symmetric(
            vertical: AppTvTokens.focusOverflow,
          ),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            crossAxisSpacing: AppTvTokens.gridGap,
            mainAxisSpacing: AppTvTokens.gridGap,
            mainAxisExtent: cardHeight + AppTvTokens.focusOverflow * 2,
          ),
          itemCount: items.length,
          itemBuilder: (context, index) {
            final movie = items[index];
            return Align(
              alignment: Alignment.topCenter,
              child: TvMovieCard(
                movie: movie,
                width: cardWidth,
                height: cardHeight,
                onPressed: () => onPressed(movie),
              ),
            );
          },
        );
      },
    );
  }
}
