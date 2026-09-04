import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';
import 'package:sakuramedia/core/network/api_client.dart';
import 'package:sakuramedia/core/network/providers/api_client_provider.dart';
import 'package:sakuramedia/widgets/domain/movies/player/movie_player_back_overlay.dart';
import 'package:sakuramedia/widgets/domain/movies/player/movie_player_mobile_drawers.dart';
import 'package:sakuramedia/widgets/domain/movies/player/movie_player_native_stats_sampler.dart';

/// 播放信息的稳定状态与展示入口。
///
/// 播放器控制条会在鼠标离开后卸载，因此分栏播放使用该控制器持有采样与本地浮层；
/// 触发按钮本身卸载不会关掉已打开的面板。
class MediaPlaybackInfoController {
  MediaPlaybackInfoController({
    required Player player,
    required ApiClient Function() readApiClient,
  }) : _player = player,
       _readApiClient = readApiClient,
       _sampler = MoviePlayerNativeStatsSampler(
         readNativeProperty: createMediaKitNativePropertyReader(player),
         originalUrl: '',
       ) {
    _attach();
  }

  final Player _player;
  final ApiClient Function() _readApiClient;
  final MoviePlayerNativeStatsSampler _sampler;
  final _subscriptions = <StreamSubscription<dynamic>>[];
  String? _activeUrl;
  int? _activeIndex;
  int _generation = 0;
  bool _panelOpen = false;
  OverlayEntry? _localPanelEntry;
  bool _isDisposed = false;

  void _attach() {
    _activeUrl = null;
    _activeIndex = null;
    _subscriptions.addAll([
      _player.stream.playlist.listen(_syncMedia),
      _player.stream.track.listen(_sampler.updateTrack),
      _player.stream.videoParams.listen(_sampler.updateVideoParams),
      _player.stream.audioParams.listen(_sampler.updateAudioParams),
      _player.stream.audioBitrate.listen(_sampler.updateAudioBitrate),
    ]);
    _syncMedia(_player.state.playlist);
    _sampler.updateTrack(_player.state.track);
    _sampler.updateVideoParams(_player.state.videoParams);
    _sampler.updateAudioParams(_player.state.audioParams);
    _sampler.updateAudioBitrate(_player.state.audioBitrate);
    _sampler.start();
  }

  void _syncMedia(Playlist playlist) {
    if (_isDisposed) return;
    final index = playlist.index;
    final url = index >= 0 && index < playlist.medias.length
        ? playlist.medias[index].uri
        : '';
    if (_activeIndex == index && _activeUrl == url) return;
    _activeIndex = index;
    _activeUrl = url;
    final generation = ++_generation;
    _sampler.reset();
    _sampler.updateContext(originalUrl: url);
    _sampler.updatePlaybackModeLabel('未确认');
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    if (RegExp(r'/media-clips/\d+/stream$').hasMatch(uri.path)) {
      _sampler.updatePlaybackModeLabel('后端代理');
      return;
    }
    final attemptId = uri.queryParameters['playback_attempt_id'];
    if (attemptId != null && RegExp(r'/media/\d+/play/$').hasMatch(uri.path)) {
      unawaited(_confirmMode(attemptId, generation));
    }
  }

  Future<void> _confirmMode(String attemptId, int generation) async {
    // playlist 通知可能先于网关响应，给本次请求少量时间登记结果。
    for (var attempt = 0; attempt < 3; attempt++) {
      await Future<void>.delayed(const Duration(seconds: 1));
      if (_isDisposed || generation != _generation) return;
      try {
        final response = await _readApiClient().get(
          '/media/playback-attempts/$attemptId',
          receiveTimeout: const Duration(seconds: 5),
        );
        if (_isDisposed || generation != _generation) return;
        final label = switch (response['mode']) {
          'direct' => '直连',
          'proxy' => '后端代理',
          _ => null,
        };
        if (label != null) {
          _sampler.updatePlaybackModeLabel(label);
          return;
        }
      } catch (_) {
        // 旧后端或查询失败不影响播放，也不根据 URL 猜测实际播放模式。
        return;
      }
    }
  }

  void showLocal(BuildContext context) {
    if (_isDisposed || _panelOpen) return;
    _panelOpen = true;
    _localPanelEntry = OverlayEntry(
      builder: (overlayContext) => Material(
        type: MaterialType.transparency,
        child: Stack(
          fit: StackFit.expand,
          children: [
            buildMoviePlayerInfoSideDrawerOverlay(
              context: overlayContext,
              isOpen: true,
              onDismiss: _dismissLocalPanel,
              infoListenable: _sampler.snapshot,
            ),
          ],
        ),
      ),
    );
    Overlay.of(context).insert(_localPanelEntry!);
  }

  void _dismissLocalPanel() {
    final entry = _localPanelEntry;
    _localPanelEntry = null;
    _panelOpen = false;
    if (entry?.mounted == true) {
      entry!.remove();
    }
  }

  void dispose() {
    if (_isDisposed) return;
    _isDisposed = true;
    _dismissLocalPanel();
    _generation++;
    for (final subscription in _subscriptions) {
      unawaited(subscription.cancel());
    }
    _subscriptions.clear();
    _sampler.dispose();
  }
}

/// 单播、合集与切片共用的信息入口；面板走根 Navigator，覆盖全屏播放路由。
class MediaPlaybackInfoButton extends StatelessWidget {
  const MediaPlaybackInfoButton({super.key, required this.player});

  final Player player;

  @override
  Widget build(BuildContext context) => MoviePlayerInfoButton(
    onPressed: () => unawaited(
      showGeneralDialog<void>(
        context: context,
        barrierLabel: '关闭播放信息',
        barrierDismissible: true,
        barrierColor: Colors.transparent,
        pageBuilder: (_, __, ___) => _MediaPlaybackInfoDialog(player: player),
      ),
    ),
  );
}

// 采样跟随弹窗生命周期，控制条隐藏卸载按钮时仍能持续更新。
class _MediaPlaybackInfoDialog extends ConsumerStatefulWidget {
  const _MediaPlaybackInfoDialog({required this.player});

  final Player player;

  @override
  ConsumerState<_MediaPlaybackInfoDialog> createState() =>
      _MediaPlaybackInfoDialogState();
}

class _MediaPlaybackInfoDialogState
    extends ConsumerState<_MediaPlaybackInfoDialog> {
  late final MediaPlaybackInfoController _controller;

  @override
  void initState() {
    super.initState();
    _controller = MediaPlaybackInfoController(
      player: widget.player,
      readApiClient: () => ref.read(apiClientProvider),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Material(
    type: MaterialType.transparency,
    child: Stack(
      fit: StackFit.expand,
      children: [
        buildMoviePlayerInfoSideDrawerOverlay(
          context: context,
          isOpen: true,
          onDismiss: () => Navigator.of(context).pop(),
          infoListenable: _controller._sampler.snapshot,
        ),
      ],
    ),
  );
}
