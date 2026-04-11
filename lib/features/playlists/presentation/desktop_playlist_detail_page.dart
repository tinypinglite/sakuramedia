import 'package:flutter/material.dart';
import 'package:sakuramedia/features/playlists/presentation/playlist_detail_content.dart';
import 'package:sakuramedia/routes/app_navigation_actions.dart';
import 'package:sakuramedia/routes/app_navigation.dart';
import 'package:sakuramedia/theme.dart';

class DesktopPlaylistDetailPage extends StatelessWidget {
  const DesktopPlaylistDetailPage({super.key, required this.playlistId});

  final int playlistId;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: context.appColors.surfaceElevated,
      child: PlaylistDetailContent(
        playlistId: playlistId,
        enablePullToRefresh: false,
        onMovieTap:
            (movie) => context.pushDesktopMovieDetail(
              movieNumber: movie.movieNumber,
              fallbackPath: buildDesktopPlaylistDetailRoutePath(playlistId),
            ),
      ),
    );
  }
}
