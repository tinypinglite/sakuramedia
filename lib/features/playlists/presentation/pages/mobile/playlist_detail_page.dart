import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/features/playlists/presentation/pages/shared/playlist_detail_content.dart';
import 'package:sakuramedia/routes/app_route_paths.dart';
import 'package:sakuramedia/routes/mobile_routes.dart';
import 'package:sakuramedia/theme.dart';

class MobilePlaylistDetailPage extends StatelessWidget {
  const MobilePlaylistDetailPage({super.key, required this.playlistId});

  final int playlistId;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      key: const Key('mobile-playlist-detail-page'),
      color: Colors.transparent,
      child: PlaylistDetailContent(
        playlistId: playlistId,
        surfaceColor: context.appColors.surfaceCard.withValues(alpha: 0.9),
        fallbackPath: mobileOverviewPath,
        enablePullToRefresh: true,
        onMovieTap: (movie) => MobileMovieDetailRouteData(
          movieNumber: movie.movieNumber,
        ).push(context),
      ),
    );
  }
}
