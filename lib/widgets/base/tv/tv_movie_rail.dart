import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/features/movies/data/dto/listing/movie_list_item_dto.dart';
import 'package:sakuramedia/l10n/app_localizations.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/feedback/app_empty_state.dart';
import 'package:sakuramedia/widgets/base/layout/scrolling/app_scroll_rail.dart';
import 'package:sakuramedia/widgets/base/tv/tv_movie_card.dart';

/// 电视首页的横向影片 rail：滚动和间距复用 [AppScrollRail]。
class TvMovieRail extends StatelessWidget {
  const TvMovieRail({super.key, required this.items, required this.onPressed});

  final List<MovieListItemDto> items;
  final ValueChanged<MovieListItemDto> onPressed;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return AppEmptyState(
        message: AppLocalizations.of(context).widgetMovieEmptyList,
        variant: AppStatePanelVariant.section,
      );
    }
    final width = AppTvTokens.posterWidth;
    final height = width / context.appComponentTokens.movieCardAspectRatio;
    return AppScrollRail(
      height: height,
      itemCount: items.length,
      itemBuilder: (context, index) {
        final movie = items[index];
        return SizedBox(
          width: width,
          child: TvMovieCard(movie: movie, onPressed: () => onPressed(movie)),
        );
      },
    );
  }
}
