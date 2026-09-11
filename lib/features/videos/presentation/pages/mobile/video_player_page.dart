import 'dart:async';

import 'package:flutter/material.dart';
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

class _MobileVideoPlayerPageState extends State<MobileVideoPlayerPage> {
  @override
  void initState() {
    super.initState();
    unawaited(enterLandscapePlayerSystemUi());
  }

  @override
  void dispose() {
    unawaited(restoreSystemUiAfterLandscapePlayer());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return VideoPlayerContent(
      videoId: widget.videoId,
      initialTitle: widget.title,
      fallbackPath: widget.fallbackPath ?? mobilePornboxPath,
      initialPositionSeconds: widget.initialPositionSeconds,
      imageSearchRoutePath: mobileImageSearchPath,
      useTouchOptimizedControls: true,
    );
  }
}
