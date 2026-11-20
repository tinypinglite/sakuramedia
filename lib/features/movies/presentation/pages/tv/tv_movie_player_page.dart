import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/features/movies/presentation/pages/shared/movie_merged_play_content.dart';
import 'package:sakuramedia/features/movies/presentation/pages/shared/movie_player_content.dart';
import 'package:sakuramedia/routes/app_routes.dart';
import 'package:sakuramedia/routes/app_route_paths.dart';

class TvMoviePlayerPage extends StatelessWidget {
  const TvMoviePlayerPage({
    super.key,
    required this.movieNumber,
    this.initialMediaId,
    this.mergedLibraryId,
    this.initialPositionSeconds,
    this.fallbackPath,
  });

  final String movieNumber;
  final int? initialMediaId;
  final int? mergedLibraryId;
  final int? initialPositionSeconds;
  final String? fallbackPath;

  @override
  Widget build(BuildContext context) {
    final resolvedFallback =
        fallbackPath ?? TvRoutes.movieDetail(movieNumber: movieNumber).location;
    if (mergedLibraryId != null) {
      return MovieMergedPlayContent(
        movieNumber: movieNumber,
        libraryId: mergedLibraryId!,
        fallbackPath: resolvedFallback,
        useTouchOptimizedControls: false,
        imageSearchRoutePath: tvHomePath,
      );
    }
    return MoviePlayerContent(
      movieNumber: movieNumber,
      initialMediaId: initialMediaId,
      initialPositionSeconds: initialPositionSeconds,
      fallbackPath: resolvedFallback,
      imageSearchRoutePath: tvHomePath,
      useTouchOptimizedControls: false,
    );
  }
}
