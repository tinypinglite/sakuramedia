import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/features/movies/data/dto/listing/movie_list_item_dto.dart';
import 'package:sakuramedia/l10n/app_localizations.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/tv/tv_movie_card.dart';

class TvMovieRail extends StatelessWidget {
  const TvMovieRail({
    super.key,
    required this.items,
    required this.onPressed,
    this.layout = TvMovieCardLayout.poster,
    this.autofocusFirst = false,
  });

  final List<MovieListItemDto> items;
  final void Function(MovieListItemDto movie) onPressed;
  final TvMovieCardLayout layout;
  final bool autofocusFirst;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return Text(
        AppLocalizations.of(context).widgetMovieEmptyList,
        style: resolveAppTextStyle(
          context,
          size: AppTextSize.s20,
          tone: AppTextTone.muted,
        ),
      );
    }
    final landscape = layout == TvMovieCardLayout.landscape;
    final cardHeight = landscape
        ? AppTvTokens.landscapeCardHeight
        : AppTvTokens.posterHeight;
    return SizedBox(
      height: cardHeight + AppTvTokens.focusOverflow * 2,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(
          vertical: AppTvTokens.focusOverflow,
        ),
        itemCount: items.length,
        separatorBuilder: (context, index) =>
            SizedBox(width: AppTvTokens.railGap),
        itemBuilder: (context, index) {
          final movie = items[index];
          return TvMovieCard(
            movie: movie,
            layout: layout,
            autofocus: autofocusFirst && index == 0,
            onPressed: () => onPressed(movie),
          );
        },
      ),
    );
  }
}
