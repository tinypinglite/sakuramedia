import 'dart:async';

import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:sakuramedia/core/format/media_timecode.dart';
import 'package:sakuramedia/theme.dart';

/// 合集「合并播放」模式下的进度条 widget：把每集时长累加成虚拟总时长，
/// 把当前集 + 集内 position 折算成虚拟总位置；UI 看上去就像在播一部完整影片。
///
/// 拖动通过 [onSeekGlobalSeconds] 回调出去（由 mixin `seekToGlobalSeconds` 处理：
/// 解出目标集 + 集内 offset → `jump` + 待目标集首个 position tick 再 `seek`）。
///
/// 内部监听 [player] 的 `playlist`/`position` 流以 setState 重绘；拖动期间用 `_dragValue`
/// 暂存避免 position tick 把游标拉回。媒体 controls 主题在合并模式下需把
/// `displaySeekBar: false` 隐藏内置 seek bar，避免与本组件出现两条进度条。
class MergedPositionIndicator extends StatefulWidget {
  const MergedPositionIndicator({
    super.key,
    required this.player,
    required this.episodeDurationsSeconds,
    required this.onSeekGlobalSeconds,
  });

  final Player player;

  /// 每集时长（秒），顺序须与 [Player] 当前 [Playlist] 一致；累加为虚拟总时长。
  final List<int> episodeDurationsSeconds;

  /// 拖动结束回调：传虚拟总位置（秒），由 mixin 解出目标集 + offset 再 seek。
  final ValueChanged<int> onSeekGlobalSeconds;

  @override
  State<MergedPositionIndicator> createState() =>
      _MergedPositionIndicatorState();
}

class _MergedPositionIndicatorState extends State<MergedPositionIndicator> {
  StreamSubscription<Duration>? _positionSub;
  StreamSubscription<Playlist>? _playlistSub;
  Duration _position = Duration.zero;
  int _episode = 0;
  double? _dragValue;

  // 累积前缀和：cumulative[i] = sum(durations[0..i-1])，size = N+1，末位 = 总秒。
  late List<int> _cumulative;

  @override
  void initState() {
    super.initState();
    _recomputeCumulative();
    final initialIndex = widget.player.state.playlist.index;
    _episode = _clampEpisode(initialIndex);
    _position = widget.player.state.position;
    _positionSub = widget.player.stream.position.listen((position) {
      if (!mounted || _dragValue != null) {
        return;
      }
      // 与 mixin `attachPlayback` position listener 同构：position 流可能先于
      // playlist 流为新集到达，若只更新 _position 不校正 _episode，会用 stale base
      // + 新集首秒位置算出「游标瞬间倒退到上一集累计起点」的错位。改用 player 实时
      // playlist.index 即可消除该跳变。
      final liveEpisode = _clampEpisode(widget.player.state.playlist.index);
      setState(() {
        _position = position;
        _episode = liveEpisode;
      });
    });
    // playlist 流仍订阅作兜底：mpv 进入新集但未立刻吐 position tick 时（如纯切换
      // 暂停状态），保证 _episode 仍能更新驱动 base 重算。
    _playlistSub = widget.player.stream.playlist.listen((playlist) {
      if (!mounted) {
        return;
      }
      setState(() => _episode = _clampEpisode(playlist.index));
    });
  }

  @override
  void didUpdateWidget(covariant MergedPositionIndicator oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_durationsEqual(
      oldWidget.episodeDurationsSeconds,
      widget.episodeDurationsSeconds,
    )) {
      _recomputeCumulative();
      _episode = _clampEpisode(_episode);
    }
  }

  @override
  void dispose() {
    _positionSub?.cancel();
    _playlistSub?.cancel();
    super.dispose();
  }

  void _recomputeCumulative() {
    final cumulative = <int>[0];
    var acc = 0;
    for (final duration in widget.episodeDurationsSeconds) {
      // 防御负值/缺数据：按 0 计入，不破坏单调递增（影响仅是该集无法精确定位）。
      acc += duration > 0 ? duration : 0;
      cumulative.add(acc);
    }
    _cumulative = cumulative;
  }

  int _clampEpisode(int index) {
    final count = widget.episodeDurationsSeconds.length;
    if (count <= 0) {
      return 0;
    }
    if (index < 0) {
      return 0;
    }
    if (index >= count) {
      return count - 1;
    }
    return index;
  }

  int get _totalSeconds => _cumulative.isEmpty ? 0 : _cumulative.last;

  double get _displaySeconds {
    final drag = _dragValue;
    if (drag != null) {
      return drag;
    }
    if (_cumulative.length <= _episode) {
      return 0;
    }
    final base = _cumulative[_episode];
    final position = (base + _position.inSeconds).toDouble();
    final total = _totalSeconds.toDouble();
    if (total <= 0) {
      return 0;
    }
    return position.clamp(0.0, total);
  }

  void _handleChanged(double value) {
    setState(() => _dragValue = value);
  }

  void _handleChangeEnd(double value) {
    final target = value.round();
    setState(() => _dragValue = null);
    widget.onSeekGlobalSeconds(target);
  }

  @override
  Widget build(BuildContext context) {
    final total = _totalSeconds;
    final current = _displaySeconds;
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;
    final textStyle = resolveAppTextStyle(
      context,
      size: AppTextSize.s12,
    ).copyWith(
      color: Colors.white,
      fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
    );
    return Expanded(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: context.appSpacing.sm),
        child: Row(
          children: [
            Text(formatMediaTimecode(current.round()), style: textStyle),
            const SizedBox(width: 12),
            Expanded(
              child: SliderTheme(
                data: SliderThemeData(
                  trackHeight: 6,
                  activeTrackColor: primary,
                  inactiveTrackColor: Colors.white24,
                  thumbColor: primary,
                  overlayColor: primary.withValues(alpha: 0.2),
                  thumbShape: const RoundSliderThumbShape(
                    enabledThumbRadius: 7,
                  ),
                  overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
                ),
                child: Slider(
                  key: const Key('merged-position-indicator-slider'),
                  value: current.clamp(0.0, total.toDouble()),
                  min: 0,
                  max: total > 0 ? total.toDouble() : 1,
                  onChanged: total > 0 ? _handleChanged : null,
                  onChangeEnd: total > 0 ? _handleChangeEnd : null,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Text(formatMediaTimecode(total), style: textStyle),
          ],
        ),
      ),
    );
  }

  bool _durationsEqual(List<int> a, List<int> b) {
    if (identical(a, b)) {
      return true;
    }
    if (a.length != b.length) {
      return false;
    }
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) {
        return false;
      }
    }
    return true;
  }
}
