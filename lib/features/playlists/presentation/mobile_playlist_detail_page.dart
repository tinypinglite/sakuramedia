import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:sakuramedia/features/playlists/presentation/playlist_detail_content.dart';
import 'package:sakuramedia/routes/app_navigation.dart';
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
        onMovieTap:
            (movie) => context.push(
              buildMobileMovieDetailRoutePath(movie.movieNumber),
              extra: buildMobilePlaylistDetailRoutePath(playlistId),
            ),
      ),
    );
  }
}
