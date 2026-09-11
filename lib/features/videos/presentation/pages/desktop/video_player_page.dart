import 'package:flutter/material.dart';
import 'package:sakuramedia/features/videos/presentation/pages/shared/video_player_content.dart';

class DesktopVideoPlayerPage extends StatelessWidget {
  const DesktopVideoPlayerPage({
    super.key,
    required this.videoId,
    this.fallbackPath,
    this.initialPositionSeconds,
  });

  final int videoId;
  final String? fallbackPath;
  final int? initialPositionSeconds;

  @override
  Widget build(BuildContext context) {
    return VideoPlayerContent(
      videoId: videoId,
      fallbackPath: fallbackPath,
      initialPositionSeconds: initialPositionSeconds,
    );
  }
}
