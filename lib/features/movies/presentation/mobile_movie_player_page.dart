import 'dart:async';

import 'package:flutter/material.dart';
import 'package:sakuramedia/features/movies/presentation/desktop_movie_player_page.dart';
import 'package:sakuramedia/routes/app_navigation.dart';
import 'package:sakuramedia/widgets/movie_player/landscape_player_system_ui.dart';

const double _mobilePlayerDividerHandleBuffer = 12;

class MobileMoviePlayerPage extends StatefulWidget {
  const MobileMoviePlayerPage({
    super.key,
    required this.movieNumber,
    this.initialMediaId,
    this.initialPositionSeconds,
    this.surfaceBuilder,
  });

  final String movieNumber;
  final int? initialMediaId;
  final int? initialPositionSeconds;
  final MoviePlayerSurfaceBuilder? surfaceBuilder;

  @override
  State<MobileMoviePlayerPage> createState() => _MobileMoviePlayerPageState();
}

class _MobileMoviePlayerPageState extends State<MobileMoviePlayerPage> {
  @override
  void initState() {
    super.initState();
    debugPrint(
      '[player-debug] mobile_player_page_init movie=${widget.movieNumber} initialMediaId=${widget.initialMediaId} initialPositionSeconds=${widget.initialPositionSeconds}',
    );
    unawaited(enterLandscapePlayerSystemUi());
  }

  @override
  void dispose() {
    unawaited(restoreSystemUiAfterLandscapePlayer());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DesktopMoviePlayerPage(
      movieNumber: widget.movieNumber,
      initialMediaId: widget.initialMediaId,
      initialPositionSeconds: widget.initialPositionSeconds,
      fallbackPath: buildMobileMovieDetailRoutePath(widget.movieNumber),
      enableThumbnailActionMenu: true,
      imageSearchRoutePath: mobileImageSearchPath,
      useTouchOptimizedControls: true,
      dividerHandleBuffer: _mobilePlayerDividerHandleBuffer,
      surfaceBuilder: widget.surfaceBuilder,
    );
  }
}
