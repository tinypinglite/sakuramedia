import 'dart:async';

import 'package:flutter/material.dart';
import 'package:sakuramedia/features/movies/presentation/pages/shared/movie_player_content.dart';
import 'package:sakuramedia/routes/app_navigation.dart';
import 'package:sakuramedia/widgets/domain/movies/player/landscape_player_system_ui.dart';

const double _mobilePlayerDividerHandleBuffer = 12;

/// 移动影片播放器壳：横屏 SystemUI 生命周期是唯一有状态职责；
/// [initialMediaId] / [initialPositionSeconds] 保留为 final 字段供路由测试直接读取，
/// 其余全部实现在共享的 [MoviePlayerContent]。
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
    return MoviePlayerContent(
      movieNumber: widget.movieNumber,
      initialMediaId: widget.initialMediaId,
      initialPositionSeconds: widget.initialPositionSeconds,
      fallbackPath: buildMobileMovieDetailRoutePath(widget.movieNumber),
      imageSearchRoutePath: mobileImageSearchPath,
      useTouchOptimizedControls: true,
      dividerHandleBuffer: _mobilePlayerDividerHandleBuffer,
      surfaceBuilder: widget.surfaceBuilder,
    );
  }
}
