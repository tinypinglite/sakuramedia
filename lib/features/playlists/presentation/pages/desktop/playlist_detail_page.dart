import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/features/playlists/presentation/pages/shared/playlist_detail_content.dart';
import 'package:sakuramedia/routes/app_navigation_actions.dart';
import 'package:sakuramedia/routes/app_navigation.dart';
import 'package:sakuramedia/routes/app_route_paths.dart';
import 'package:sakuramedia/theme.dart';

class DesktopPlaylistDetailPage extends StatelessWidget {
  const DesktopPlaylistDetailPage({
    super.key,
    required this.playlistId,
    this.movieFallbackPath,
  });

  final int playlistId;

  /// 从影片详情返回时的落点；默认回到当前播放列表详情。
  final String? movieFallbackPath;

  @override
  Widget build(BuildContext context) {
    return PlaylistDetailContent(
      playlistId: playlistId,
      surfaceColor: context.appColors.surfacePage,
      fallbackPath: desktopPlaylistsPath,
      enablePullToRefresh: false,
      onMovieTap: (movie) => context.pushDesktopMovieDetail(
        movieNumber: movie.movieNumber,
        fallbackPath:
            movieFallbackPath ??
            buildDesktopPlaylistDetailRoutePath(playlistId),
      ),
    );
  }
}
