import 'dart:async';

import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:provider/provider.dart';
import 'package:sakuramedia/core/media/media_url_resolver.dart';
import 'package:sakuramedia/core/session/session_store.dart';
import 'package:sakuramedia/widgets/base/feedback/app_empty_state.dart';
import 'package:sakuramedia/widgets/media_player/landscape_player_system_ui.dart';
import 'package:sakuramedia/widgets/media_player/movie_player_back_overlay.dart';
import 'package:sakuramedia/widgets/media_player/movie_player_surface.dart';
import 'package:sakuramedia/widgets/media_player/themed_video_player.dart';

/// 移动端单切片全屏横屏播放页：进入锁定横屏沉浸式、退出恢复原方向。
///
/// 切片很短，无需缩略图 / 进度上报 / 字幕，用 media_kit 直接播放签名 `streamUrl`，
/// 播放控件与合集连播页保持一致（去掉上一首 / 下一首）。
class MobileClipPlayerPage extends StatefulWidget {
  const MobileClipPlayerPage({
    super.key,
    required this.streamUrl,
    required this.title,
  });

  final String streamUrl;
  final String title;

  @override
  State<MobileClipPlayerPage> createState() => _MobileClipPlayerPageState();
}

class _MobileClipPlayerPageState extends State<MobileClipPlayerPage> {
  Player? _player;
  VideoController? _controller;
  bool _hasResolvedUrl = true;

  @override
  void initState() {
    super.initState();
    unawaited(enterLandscapePlayerSystemUi());
    WidgetsBinding.instance.addPostFrameCallback((_) => _open());
  }

  @override
  void dispose() {
    unawaited(restoreSystemUiAfterLandscapePlayer());
    _player?.dispose();
    super.dispose();
  }

  void _open() {
    if (!mounted) {
      return;
    }
    final baseUrl = context.read<SessionStore>().baseUrl;
    final resolvedUrl = resolveMediaUrl(
      rawUrl: widget.streamUrl,
      baseUrl: baseUrl,
    );
    if (resolvedUrl == null || resolvedUrl.isEmpty) {
      setState(() => _hasResolvedUrl = false);
      return;
    }
    final player = Player();
    final controller = VideoController(
      player,
      configuration: const VideoControllerConfiguration(hwdec: 'auto'),
    );
    setState(() {
      _player = player;
      _controller = controller;
    });
    player.open(Media(resolvedUrl));
  }

  void _handleBack() {
    // 本页用 Navigator.push（rootNavigator）推入、不在 go_router 栈内，
    // 故用 Navigator 自身 pop，而非 go_router 的 context.pop。
    Navigator.of(context).maybePop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(backgroundColor: Colors.black, body: _buildBody(context));
  }

  Widget _buildBody(BuildContext context) {
    if (!_hasResolvedUrl) {
      return wrapWithMoviePlayerBackButton(
        onBackPressed: _handleBack,
        backButtonKey: const Key('mobile-clip-player-back-button'),
        child: const Center(child: AppEmptyState(message: '无效的播放地址')),
      );
    }
    final controller = _controller;
    if (controller == null) {
      return wrapWithMoviePlayerBackButton(
        onBackPressed: _handleBack,
        backButtonKey: const Key('mobile-clip-player-back-button'),
        child: const Center(child: CircularProgressIndicator()),
      );
    }
    return _buildPlayerSurface(context, controller);
  }

  Widget _buildPlayerSurface(
    BuildContext context,
    VideoController videoController,
  ) {
    final title = widget.title.trim();
    return ThemedVideoPlayer(
      videoController: videoController,
      useTouchOptimizedControls: true,
      videoKey: const Key('mobile-clip-player-video'),
      topControls: buildMoviePlayerTopControls(
        movieNumber: title.isEmpty ? '切片' : title,
        onBackPressed: _handleBack,
      ),
      bottomControls: const <Widget>[
        MaterialPlayOrPauseButton(),
        MaterialPositionIndicator(),
        Spacer(),
        MaterialFullscreenButton(),
      ],
    );
  }
}
