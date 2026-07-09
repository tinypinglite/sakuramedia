import 'dart:async';

import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:sakuramedia/widgets/domain/collections/playback/collection_filmstrip_controller.dart';
import 'package:sakuramedia/widgets/domain/collections/playback/collection_playback_mode.dart';
import 'package:sakuramedia/widgets/domain/media/movie_media_thumbnail_grid.dart';
import 'package:sakuramedia/widgets/domain/media/movie_player_thumbnail_panel.dart';

/// 合集连播底栏：含上一首 / 下一首 + 全屏左侧的「选集」按钮。按平台选对应控件
/// 变体——移动用触摸版、桌面用 Desktop 版（多一个音量按钮）。
/// [includeEpisodeButton] 为 `false` 时省略「选集」按钮（全屏态用，浮层在全屏不可见）。
/// [progressIndicator] 非空时替换默认的 [MaterialPositionIndicator]（时间文字），
/// 用于合并模式接管整段进度条 + 时间显示（占满中间剩余空间，含 [Expanded] 自身）。
List<Widget> buildCollectionPlayBottomControls({
  required bool useTouchOptimizedControls,
  required VoidCallback onOpenEpisodes,
  bool includeEpisodeButton = true,
  Widget? progressIndicator,
}) {
  if (useTouchOptimizedControls) {
    return <Widget>[
      const MaterialSkipPreviousButton(),
      const MaterialPlayOrPauseButton(),
      const MaterialSkipNextButton(),
      if (progressIndicator != null)
        progressIndicator
      else ...[
        const MaterialPositionIndicator(),
        const Spacer(),
      ],
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
    if (progressIndicator != null)
      progressIndicator
    else ...[
      const MaterialPositionIndicator(),
      const Spacer(),
    ],
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

  /// 「选集」浮层开合状态。切片 / 视频合集页公用同一套状态与 open/close 方法。
  bool isEpisodePanelOpen = false;

  /// 打开「选集」浮层。已开时无副作用。
  void openEpisodePanel() {
    if (isEpisodePanelOpen) return;
    setState(() => isEpisodePanelOpen = true);
  }

  /// 关闭「选集」浮层。已关时无副作用。
  void closeEpisodePanel() {
    if (!isEpisodePanelOpen) return;
    setState(() => isEpisodePanelOpen = false);
  }

  /// 播放形态；[CollectionPlaybackMode.merged] 时由页面接管底栏进度条 + 隐藏内置 seek bar。
  CollectionPlaybackMode playbackMode = CollectionPlaybackMode.playlist;

  /// 每集时长（秒），与可播 [Playlist] 顺序对齐；合并模式下供进度条累加为虚拟总时长。
  /// playlist 模式可不传（保持空列表）。
  List<int> episodeDurationsSeconds = const <int>[];

  StreamSubscription<Playlist>? _playlistSub;
  StreamSubscription<Duration>? _positionSub;
  StreamSubscription<Duration>? _pendingSeekSub;

  /// 待目标集就绪后补做的跨集 seek；null = 无待办。
  ({int episodeIndex, int offsetSeconds})? _pendingSeek;

  /// 在 `setState` 内调用：登记播放器/面板并接线 playlist/position 流。
  ///
  /// [mode] 与 [episodeDurationsSeconds] 用于合并播放形态：前者切换 UI（隐藏内置 seek bar
  /// 改用 `MergedPositionIndicator`），后者驱动虚拟总时长 / `seekToGlobalSeconds` 反向定位。
  /// 默认 [CollectionPlaybackMode.playlist]、空列表，行为与旧版完全一致。
  void attachPlayback({
    required Player player,
    required VideoController videoController,
    required CollectionFilmstripController filmstrip,
    required int startIndex,
    CollectionPlaybackMode mode = CollectionPlaybackMode.playlist,
    List<int> episodeDurationsSeconds = const <int>[],
  }) {
    this.player = player;
    this.videoController = videoController;
    this.filmstrip = filmstrip;
    playbackMode = mode;
    this.episodeDurationsSeconds = episodeDurationsSeconds;
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
    // 「有效当前集」：有在途跨集 jump 时，实时 playlist.index 仍是旧集、不可信，
    // 真正即将到达的是待办的目标集；无待办时才用实时 index 判同集。
    final currentEpisode =
        _pendingSeek?.episodeIndex ?? activePlayer.state.playlist.index;
    if (target.episodeIndex == currentEpisode) {
      if (_pendingSeek != null) {
        // 在途 jump 正是去这一集：只更新待办 offset，待该集首个 tick 再 seek。此刻
        // 播放器还停在旧集，若立即 seek 会落到旧集的错误位置。
        _pendingSeek = target;
      } else {
        // 真·同集：先清掉任何已 arm 的一次性跨集 seek 监听（_handlePlaylist 消费完待办后
        // 会留下它等首个 tick），避免它在本次同集 seek 之后又把进度覆盖回旧 offset。
        _clearPendingSeek();
        activePlayer.seek(Duration(seconds: target.offsetSeconds));
      }
      return;
    }
    // 改跳到另一集（含「ep5 jump 在途时点回当前实播的 ep1」）：覆盖旧待办、取消其已
    // arm 的旧监听，再 jump 到新目标集。否则旧监听会在新集 tick 上 seek 到旧 offset。
    _clearPendingSeek();
    _pendingSeek = target;
    unawaited(activePlayer.jump(target.episodeIndex));
  }

  void _clearPendingSeek() {
    _pendingSeek = null;
    _pendingSeekSub?.cancel();
    _pendingSeekSub = null;
  }

  /// 合并模式拖进度条：把「虚拟总秒」解到目标集 + 集内 offset，复用
  /// [seekToFrame] 的同集/跨集分支（含 jump 后待目标集首个 position tick 再 seek 的补偿）。
  void seekToGlobalSeconds(int globalSeconds) {
    final activePlayer = player;
    final durations = episodeDurationsSeconds;
    if (activePlayer == null || durations.isEmpty) {
      return;
    }
    // 解出目标集：线性扫累积时长（集数小，O(N) 够用），最后一集兜底落点防越界。
    final clamped = globalSeconds < 0 ? 0 : globalSeconds;
    var cumulative = 0;
    var targetEpisode = durations.length - 1;
    var offsetSeconds = 0;
    for (var i = 0; i < durations.length; i++) {
      final duration = durations[i] > 0 ? durations[i] : 0;
      if (clamped < cumulative + duration) {
        targetEpisode = i;
        offsetSeconds = clamped - cumulative;
        break;
      }
      cumulative += duration;
      if (i == durations.length - 1) {
        // 落到末尾或更后：定位到末集「末尾前 1 秒」。seek 到正好 duration 等同
        // EOF，mpv 会自动到下一集（若 Playlist 还有）/ 反复触发 completed 事件，
        // 不是用户拖到最右端期望的「在末尾静止」。留 1 秒裕量足够规避。
        offsetSeconds = duration > 0 ? duration - 1 : 0;
      }
    }
    // 与 [seekToFrame] 的同集/跨集分支保持一致：避免在途 jump 时 seek 落到旧集。
    final currentEpisode =
        _pendingSeek?.episodeIndex ?? activePlayer.state.playlist.index;
    if (targetEpisode == currentEpisode) {
      if (_pendingSeek != null) {
        _pendingSeek = (
          episodeIndex: targetEpisode,
          offsetSeconds: offsetSeconds,
        );
      } else {
        _clearPendingSeek();
        activePlayer.seek(Duration(seconds: offsetSeconds));
      }
      return;
    }
    _clearPendingSeek();
    _pendingSeek = (episodeIndex: targetEpisode, offsetSeconds: offsetSeconds);
    unawaited(activePlayer.jump(targetEpisode));
  }

  /// 右面板「整部合集」关键帧网格（纯展示 + 高亮 + 点击跳转；失败静默降级）。
  ///
  /// [onThumbnailMenuRequested]：右键/长按某帧的菜单回调（index 为 [filmstrip] 全局帧下标，
  /// 与 `thumbnails` 同坐标系）。传 `null`（默认）则不挂菜单——切片合集无 media 不支持时刻，
  /// 故只 pornbox 页传入「添加时刻」菜单。仍不传圈选回调 → 圈选 UI 始终隐藏。
  ///
  /// [layout]：默认统一 16:9 网格（与历史观感一致）；pornbox 合集页传 [ThumbnailGridLayout.staggered]
  /// 走瀑布流，按帧自带 width/height 排版，混合横竖图不再两侧留底。
  Widget buildFilmstripPanel({
    void Function(int index, Offset globalPosition)? onThumbnailMenuRequested,
    ThumbnailGridLayout layout = ThumbnailGridLayout.uniform16x9,
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
              layout: layout,
            );
          },
        );
      },
    );
  }
}
