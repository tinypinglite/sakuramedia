import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:sakuramedia/features/playlists/presentation/playlist_detail_content.dart';
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
        onMovieTap:
            (movie) => context.go(
              '/desktop/library/movies/${movie.movieNumber}',
              extra: '$desktopPlaylistsPath/$playlistId',
            ),
      ),
    );
  }
}
