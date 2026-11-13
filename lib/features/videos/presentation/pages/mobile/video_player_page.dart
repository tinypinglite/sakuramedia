import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/features/videos/presentation/pages/shared/video_player_content.dart';
import 'package:sakuramedia/routes/app_route_paths.dart';
import 'package:sakuramedia/widgets/domain/movies/player/landscape_player_system_ui.dart';

class MobileVideoPlayerPage extends StatefulWidget {
  const MobileVideoPlayerPage({
    super.key,
    required this.videoId,
    this.title,
    this.fallbackPath,
    this.initialPositionSeconds,
  });

  final int videoId;
  final String? title;
  final String? fallbackPath;
  final int? initialPositionSeconds;

  @override
  State<MobileVideoPlayerPage> createState() => _MobileVideoPlayerPageState();
}

class _MobileVideoPlayerPageState extends State<MobileVideoPlayerPage>
    with PlayerOrientationLockStateMixin<MobileVideoPlayerPage> {
  @override
  Widget build(BuildContext context) {
    return wrapWithPlayerImmersiveOverlay(
      VideoPlayerContent(
        videoId: widget.videoId,
        initialTitle: widget.title,
        fallbackPath: widget.fallbackPath ?? mobilePornboxPath,
        initialPositionSeconds: widget.initialPositionSeconds,
        imageSearchRoutePath: mobileImageSearchPath,
        useTouchOptimizedControls: true,
        orientationLock: orientationLock,
      ),
    );
  }
}
