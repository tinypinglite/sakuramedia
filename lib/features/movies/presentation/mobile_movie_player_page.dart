import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sakuramedia/features/movies/presentation/desktop_movie_player_page.dart';
import 'package:sakuramedia/routes/app_navigation.dart';

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

enum _OrientationCategory { portrait, landscape }

class _MobileMoviePlayerPageState extends State<MobileMoviePlayerPage> {
  _OrientationCategory? _entryOrientation;

  @override
  void initState() {
    super.initState();
    debugPrint(
      '[player-debug] mobile_player_page_init movie=${widget.movieNumber} initialMediaId=${widget.initialMediaId} initialPositionSeconds=${widget.initialPositionSeconds}',
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      final orientation = MediaQuery.orientationOf(context);
      _entryOrientation =
          orientation == Orientation.landscape
              ? _OrientationCategory.landscape
              : _OrientationCategory.portrait;
      unawaited(_enterPlayerSystemUi());
    });
  }

  @override
  void dispose() {
    final restoreOrientations =
        _entryOrientation == _OrientationCategory.landscape
            ? const <DeviceOrientation>[
              DeviceOrientation.landscapeLeft,
              DeviceOrientation.landscapeRight,
            ]
            : const <DeviceOrientation>[
              DeviceOrientation.portraitUp,
              DeviceOrientation.portraitDown,
            ];
    unawaited(_restoreSystemUi(restoreOrientations));
    super.dispose();
  }

  Future<void> _enterPlayerSystemUi() async {
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    await SystemChrome.setPreferredOrientations(const <DeviceOrientation>[
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
  }

  Future<void> _restoreSystemUi(
    List<DeviceOrientation> restoreOrientations,
  ) async {
    await SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.manual,
      overlays: SystemUiOverlay.values,
    );
    await SystemChrome.setPreferredOrientations(restoreOrientations);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(
        SystemChrome.setEnabledSystemUIMode(
          SystemUiMode.manual,
          overlays: SystemUiOverlay.values,
        ),
      );
    });
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
      useTouchOptimizedControls: false,
      surfaceBuilder: widget.surfaceBuilder,
    );
  }
}
