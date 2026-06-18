import 'dart:async';

import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:sakuramedia/widgets/movie_player/collection_filmstrip_controller.dart';
import 'package:sakuramedia/widgets/movie_player/movie_player_thumbnail_panel.dart';

/// 合集连播底栏：含上一首 / 下一首 + 全屏左侧的「选集」按钮。按平台选对应控件
/// 变体——移动用触摸版、桌面用 Desktop 版（多一个音量按钮）。
/// [includeEpisodeButton] 为 `false` 时省略「选集」按钮（全屏态用，浮层在全屏不可见）。
List<Widget> buildCollectionPlayBottomControls({
  required bool useTouchOptimizedControls,
  required VoidCallback onOpenEpisodes,
  bool includeEpisodeButton = true,
}) {
  if (useTouchOptimizedControls) {
    return <Widget>[
      const MaterialSkipPreviousButton(),
      const MaterialPlayOrPauseButton(),
      const MaterialSkipNextButton(),
      const MaterialPositionIndicator(),
      const Spacer(),
      if (includeEpisodeButton)
        MaterialCustomButton(
          onPressed: onOpenEpisodes,
          icon: const Icon(Icons.playlist_play_rounded),
        ),
      const MaterialFullscreenButton(),
    ];
  }
  return <Widget>[
    const MaterialDesktopSkipPreviousButton(),
    const MaterialPlayOrPauseButton(),
    const MaterialDesktopSkipNextButton(),
    const MaterialDesktopVolumeButton(),
    const MaterialPositionIndicator(),
    const Spacer(),
    if (includeEpisodeButton)
      MaterialDesktopCustomButton(
        onPressed: onOpenEpisodes,
        icon: const Icon(Icons.playlist_play_rounded),
      ),
    const MaterialFullscreenButton(),
  ];
}

/// 两个合集连播页（切片 / 视频）共享的播放装配与「整部合集」关键帧面板接线。
///
/// 抽出二者**逐字相同**且脆弱的部分：media_kit 播放器/字幕流订阅、跨集 seek 补偿
/// （`jump` 后立刻 `seek` 会失效，需待目标集首个 position tick 再 seek）、缩略图点击
/// 跳转、以及关键帧面板的构建。各页只保留自己的 `_load`、剧集列表、底栏与 `_QueueItem`。
///
/// 用法：`with CollectionPlaybackPageMixin<MyPage>`，在 `_load` 组装好 [Player]/
/// [VideoController]/[CollectionFilmstripController] 后于 `setState` 内调 [attachPlayback]，
/// 在 `dispose` 调 [disposePlayback]，`build` 用 [currentIndex]/[videoController]/
/// [filmstrip] 与 [buildFilmstripPanel]/[jumpTo]。
mixin CollectionPlaybackPageMixin<T extends StatefulWidget> on State<T> {
  Player? player;
  VideoController? videoController;
  CollectionFilmstripController? filmstrip;

  /// 当前集下标（实际可播列表）；由 playlist 流驱动 `setState`，供选集浮层高亮。
  int currentIndex = 0;

  StreamSubscription<Playlist>? _playlistSub;
  StreamSubscription<Duration>? _positionSub;
  StreamSubscription<Duration>? _pendingSeekSub;

  /// 待目标集就绪后补做的跨集 seek；null = 无待办。
  ({int episodeIndex, int offsetSeconds})? _pendingSeek;

  /// 在 `setState` 内调用：登记播放器/面板并接线 playlist/position 流。
  void attachPlayback({
    required Player player,
    required VideoController videoController,
    required CollectionFilmstripController filmstrip,
    required int startIndex,
  }) {
    this.player = player;
    this.videoController = videoController;
    this.filmstrip = filmstrip;
    currentIndex = startIndex;
    _playlistSub = player.stream.playlist.listen(_handlePlaylist);
    _positionSub = player.stream.position.listen((position) {
      // 用播放器的**实时** index 而非可能滞后的 currentIndex：position 流可能先于
      // playlist 流为新集触发，用 currentIndex 会把进度记到上一集、错位高亮。
      filmstrip.updatePosition(player.state.playlist.index, position.inSeconds);
    });
  }

  void disposePlayback() {
    _playlistSub?.cancel();
    _positionSub?.cancel();
    _pendingSeekSub?.cancel();
    filmstrip?.dispose();
    player?.dispose();
  }

  Future<void> jumpTo(int index) async {
    await player?.jump(index);
  }

  void _handlePlaylist(Playlist playlist) {
    if (!mounted) {
      return;
    }
    if (playlist.index != currentIndex) {
      setState(() => currentIndex = playlist.index);
    }
    // 跨集跳转：jump 切到目标集后，待该集首个 position tick（已就绪）再补 seek。
    final pending = _pendingSeek;
    final activePlayer = player;
    if (pending != null &&
        activePlayer != null &&
        playlist.index == pending.episodeIndex) {
      _pendingSeek = null;
      _armPendingSeek(activePlayer, pending.offsetSeconds);
    }
  }

  /// arm 一个一次性 position 监听：目标集首个 tick 到达即 seek 后自我取消。
  void _armPendingSeek(Player activePlayer, int offsetSeconds) {
    _pendingSeekSub?.cancel();
    _pendingSeekSub = activePlayer.stream.position.listen((_) {
      _pendingSeekSub?.cancel();
      _pendingSeekSub = null;
      activePlayer.seek(Duration(seconds: offsetSeconds));
    });
  }

  /// 点击「整部合集」缩略图：定位到该帧所属集的对应时间（必要时跨集）。
  void seekToFrame(int globalIndex) {
    final target = filmstrip?.resolveTarget(globalIndex);
    final activePlayer = player;
    if (target == null || activePlayer == null) {
      return;
    }
    // 同集直接 seek，并清掉任何在途的待办跨集 seek（避免被旧待办覆盖回跳）。
    if (target.episodeIndex == activePlayer.state.playlist.index) {
      _clearPendingSeek();
      activePlayer.seek(Duration(seconds: target.offsetSeconds));
      return;
    }
    // 覆盖上一个未完成的待办，并取消其已 arm 的旧监听——否则旧监听会在新目标集的
    // position tick 上 seek 到旧 offset，落到错误位置。
    _clearPendingSeek();
    _pendingSeek = target;
    unawaited(activePlayer.jump(target.episodeIndex));
  }

  void _clearPendingSeek() {
    _pendingSeek = null;
    _pendingSeekSub?.cancel();
    _pendingSeekSub = null;
  }

  /// 右面板「整部合集」关键帧网格（纯展示 + 高亮 + 点击跳转；失败静默降级）。
  ///
  /// [onThumbnailMenuRequested]：右键/长按某帧的菜单回调（index 为 [filmstrip] 全局帧下标，
  /// 与 `thumbnails` 同坐标系）。传 `null`（默认）则不挂菜单——切片合集无 media 不支持时刻，
  /// 故只 pornbox 页传入「添加时刻」菜单。仍不传圈选回调 → 圈选 UI 始终隐藏。
  Widget buildFilmstripPanel({
    void Function(int index, Offset globalPosition)? onThumbnailMenuRequested,
  }) {
    final activeFilmstrip = filmstrip;
    if (activeFilmstrip == null) {
      return const SizedBox.expand();
    }
    return AnimatedBuilder(
      animation: activeFilmstrip,
      builder: (context, _) {
        return ValueListenableBuilder<int?>(
          valueListenable: activeFilmstrip.activeIndex,
          builder: (context, activeIndex, __) {
            return MoviePlayerThumbnailPanel(
              thumbnails: activeFilmstrip.thumbnails,
              isLoading: activeFilmstrip.isLoading,
              // filmstrip 失败静默降级（缺帧的集自然为空），不暴露硬错误态。
              errorMessage: null,
              columns: activeFilmstrip.columns,
              activeIndex: activeIndex,
              isScrollLocked: activeFilmstrip.isScrollLocked,
              usesAutoColumns: activeFilmstrip.usesAutoColumns,
              onAutoColumnsResolved: activeFilmstrip.applyAutoColumns,
              onColumnsChanged: activeFilmstrip.setColumns,
              onToggleScrollLock: activeFilmstrip.toggleScrollLock,
              onThumbnailTap: seekToFrame,
              onThumbnailMenuRequested: onThumbnailMenuRequested,
              // filmstrip 失败静默降级、不暴露错误态，retry 不会被触发。
              onRetry: () {},
              // 不传圈选回调 → 圈选 UI 始终隐藏。
            );
          },
        );
      },
    );
  }
}
