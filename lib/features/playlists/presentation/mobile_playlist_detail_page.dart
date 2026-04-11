import 'package:flutter/material.dart';
import 'package:sakuramedia/features/playlists/presentation/playlist_detail_content.dart';
import 'package:sakuramedia/routes/mobile_routes.dart';
import 'package:sakuramedia/theme.dart';

class MobilePlaylistDetailPage extends StatelessWidget {
  const MobilePlaylistDetailPage({super.key, required this.playlistId});

  final int playlistId;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      key: const Key('mobile-playlist-detail-page'),
      color: context.appColors.surfaceCard,
      child: PlaylistDetailContent(
        playlistId: playlistId,
        enablePullToRefresh: true,
        onMovieTap:
            (movie) => MobileMovieDetailRouteData(
              movieNumber: movie.movieNumber,
            ).push(context),
      ),
    );
  }
}
