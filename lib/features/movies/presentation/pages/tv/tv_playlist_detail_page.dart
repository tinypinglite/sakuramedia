import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/features/movies/presentation/pages/tv/tv_movie_summary_grid_page.dart';
import 'package:sakuramedia/features/movies/presentation/providers/movie_summary_scope.dart';
import 'package:sakuramedia/l10n/app_localizations.dart';

class TvPlaylistDetailPage extends StatelessWidget {
  const TvPlaylistDetailPage({
    super.key,
    required this.playlistId,
    this.playlistName,
  });

  final int playlistId;
  final String? playlistName;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return TvMovieSummaryGridPage(
      scope: MovieSummaryScope.playlist(playlistId: playlistId, pageSize: 36),
      title: playlistName?.trim().isNotEmpty ?? false
          ? playlistName!.trim()
          : l10n.routePlaylistDetailsTitle,
      pageKey: const Key('tv-playlist-detail-page'),
    );
  }
}
