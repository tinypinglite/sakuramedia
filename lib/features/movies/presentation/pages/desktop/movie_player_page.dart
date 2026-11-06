import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/features/movies/presentation/pages/shared/movie_player_content.dart';
import 'package:sakuramedia/features/movies/presentation/pages/shared/movie_merged_play_content.dart';
import 'package:sakuramedia/routes/app_navigation.dart';
import 'package:sakuramedia/routes/app_routes.dart';

/// 桌面影片播放器壳：平台差异只有参数值（fallbackPath 来自路由、图搜走桌面路由、
/// 非触摸控制、无分割条缓冲），全部实现在共享的 [MoviePlayerContent]。
class DesktopMoviePlayerPage extends StatelessWidget {
  const DesktopMoviePlayerPage({
    super.key,
    required this.movieNumber,
    this.initialMediaId,
    this.mergedLibraryId,
    this.initialPositionSeconds,
    this.fallbackPath,
    this.imageSearchRoutePath = desktopImageSearchPath,
    this.useTouchOptimizedControls = false,
    this.dividerHandleBuffer = 0,
  });

  final String movieNumber;
  final int? initialMediaId;
  final int? mergedLibraryId;
  final int? initialPositionSeconds;
  final String? fallbackPath;
  final String imageSearchRoutePath;
  final bool useTouchOptimizedControls;
  final double dividerHandleBuffer;

  @override
  Widget build(BuildContext context) {
    if (mergedLibraryId != null) {
      return MovieMergedPlayContent(
        movieNumber: movieNumber,
        libraryId: mergedLibraryId!,
        fallbackPath:
            fallbackPath ??
            DesktopRoutes.movieDetail(movieNumber: movieNumber).location,
        useTouchOptimizedControls: useTouchOptimizedControls,
        imageSearchRoutePath: imageSearchRoutePath,
      );
    }
    return MoviePlayerContent(
      movieNumber: movieNumber,
      initialMediaId: initialMediaId,
      initialPositionSeconds: initialPositionSeconds,
      fallbackPath: fallbackPath,
      imageSearchRoutePath: imageSearchRoutePath,
      useTouchOptimizedControls: useTouchOptimizedControls,
      dividerHandleBuffer: dividerHandleBuffer,
    );
  }
}
