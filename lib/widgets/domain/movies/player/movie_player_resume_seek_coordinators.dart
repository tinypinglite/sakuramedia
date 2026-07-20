import 'dart:async';

import 'package:flutter/foundation.dart';

/// 续播提示状态机(从 `_MoviePlayerSurfaceState` 抽出的引擎件)。
///
/// 语义:媒体始终先从头播放,surface ready 后弹「继续播放?」提示;
/// - 用户点「继续」→ [resume]:seek 到历史位置并 play,完成后回调;
/// - 用户点「从头」/发生外部 seek → [resolve]:收起并回调;
/// - 换片 → [beginSession];resumePosition 被清空 → [cancel](静默收起,**不**回调);
/// - 位置流喂 [onPosition]:检测到用户自行拖动(位移超出正常播放推进)时自动 resolve。
///
/// 状态变化经 [ChangeNotifier] 通知,宿主 State 监听后 setState;
/// 播放命令与回调均构造注入,可纯 Dart 测试。
class MoviePlayerResumePromptCoordinator extends ChangeNotifier {
  MoviePlayerResumePromptCoordinator({
    required Future<void> Function(Duration position) seek,
    required Future<void> Function() play,
    required Duration Function() currentPosition,
    required double Function() playbackRate,
    void Function()? onResolved,
    void Function()? onResumeCompleted,
  })  : _seek = seek,
        _play = play,
        _currentPosition = currentPosition,
        _playbackRate = playbackRate,
        _onResolved = onResolved,
        _onResumeCompleted = onResumeCompleted;

  final Future<void> Function(Duration position) _seek;
  final Future<void> Function() _play;
  final Duration Function() _currentPosition;
  final double Function() _playbackRate;
  final void Function()? _onResolved;
  final void Function()? _onResumeCompleted;

  bool _visible = false;
  bool _resolved = true;
  Duration? _lastPosition;
  DateTime? _lastPositionAt;

  bool get isVisible => _visible;
  bool get isResolved => _resolved;

  /// 开播新媒体:有历史位置则进入「待询问」,否则视为已解决。
  void beginSession({required bool hasResumePosition}) {
    _visible = false;
    _resolved = !hasResumePosition;
    _lastPosition = null;
    _lastPositionAt = null;
    notifyListeners();
  }

  /// resumePosition 被外部清空:静默收起,不触发 onResolved 回调。
  void cancel() {
    _visible = false;
    _resolved = true;
    notifyListeners();
  }

  /// 重新收到历史位置(didUpdateWidget):回到「待询问」;
  /// surface 已 ready 则立即弹出。
  void rearm({required bool surfaceReady}) {
    _resolved = false;
    if (surfaceReady) {
      show();
    } else {
      notifyListeners();
    }
  }

  /// 弹出提示,并记录当前位置作为「用户是否自行拖动」的运动基线。
  void show() {
    _lastPosition = _currentPosition();
    _lastPositionAt = DateTime.now();
    _visible = true;
    notifyListeners();
  }

  /// 位置流探针:提示可见期间,位移明显超出「正常播放推进 + 容差」
  /// (前跳)或回退超 2s,视为用户已自行定位,自动 resolve。
  void onPosition(Duration position) {
    if (!_visible || _resolved) {
      return;
    }
    final previousPosition = _lastPosition;
    final previousAt = _lastPositionAt;
    final now = DateTime.now();
    _lastPosition = position;
    _lastPositionAt = now;
    if (previousPosition == null || previousAt == null) {
      return;
    }
    final elapsedMilliseconds = now.difference(previousAt).inMilliseconds;
    final expectedForwardMilliseconds =
        (elapsedMilliseconds * _playbackRate()).round() + 2000;
    final deltaMilliseconds =
        position.inMilliseconds - previousPosition.inMilliseconds;
    if (deltaMilliseconds < -2000 ||
        deltaMilliseconds > expectedForwardMilliseconds) {
      resolve();
    }
  }

  /// 收起提示并触发 onResolved(幂等)。
  void resolve() {
    if (_resolved) {
      return;
    }
    _resolved = true;
    _visible = false;
    notifyListeners();
    _onResolved?.call();
  }

  /// 用户选择「继续播放」:seek 到历史位置并恢复播放,完成后
  /// 触发 onResumeCompleted(无论 seek 成败)。
  void resume(Duration? position) {
    if (position == null) {
      resolve();
      return;
    }
    _resolved = true;
    _visible = false;
    notifyListeners();
    unawaited(() async {
      try {
        await _seek(position);
        await _play();
      } finally {
        _onResumeCompleted?.call();
      }
    }());
  }
}

/// 起播 seek 重试状态机(从 `_MoviePlayerSurfaceState` 抽出的引擎件)。
///
/// 场景:115/HLS 源上 open 时的初始 seek 偶尔被静默吞掉。开播后在
/// [maxWindowMs] 窗口内用位置流探针验证「已接近目标」([minNearSamples]
/// 个连续样本);不达标且过了 [retryDelayMs] 冷却则补发 seek,最多
/// [maxRetries] 次;窗口耗尽放弃。
class MoviePlayerStartupSeekCoordinator {
  MoviePlayerStartupSeekCoordinator({
    required Future<void> Function(Duration position) seek,
    required bool Function() isSurfaceReady,
    DateTime Function()? now,
  })  : _seek = seek,
        _isSurfaceReady = isSurfaceReady,
        _now = now ?? DateTime.now;

  static const int toleranceSeconds = 2;
  static const int retryDelayMs = 800;
  static const int maxWindowMs = 8000;
  static const int maxRetries = 2;
  static const int minNearSamples = 2;

  final Future<void> Function(Duration position) _seek;
  final bool Function() _isSurfaceReady;
  final DateTime Function() _now;

  Duration? _target;
  DateTime? _startedAt;
  bool _settled = true;
  int _retryCount = 0;
  int _nearTargetSamples = 0;

  /// 当前守卫的目标位置(无目标 / 已 settle 时探针不工作)。
  Duration? get target => _target;

  /// 开播新媒体:`initialPosition > 0` 才进入守卫,否则直接 settle。
  void begin(Duration? initialPosition) {
    _target = initialPosition != null && initialPosition > Duration.zero
        ? initialPosition
        : null;
    _startedAt = _now();
    _retryCount = 0;
    _nearTargetSamples = 0;
    _settled = _target == null;
  }

  /// 位置流探针:验证 / 重试 / 放弃。
  void onPosition(Duration currentPosition) {
    final target = _target;
    if (target == null || _settled) {
      return;
    }
    if (!_isSurfaceReady()) {
      return;
    }
    final startedAt = _startedAt;
    if (startedAt == null) {
      _settled = true;
      return;
    }
    final elapsedMs = _now().difference(startedAt).inMilliseconds;
    final currentSeconds = currentPosition.inSeconds;
    final targetSeconds = target.inSeconds;
    final isNearTarget = currentSeconds >= targetSeconds - toleranceSeconds;

    debugPrint(
      '[player-debug] startup_seek_probe currentSeconds=$currentSeconds targetSeconds=$targetSeconds elapsedMs=$elapsedMs retries=$_retryCount nearSamples=$_nearTargetSamples',
    );

    if (isNearTarget) {
      _nearTargetSamples++;
    } else {
      _nearTargetSamples = 0;
    }

    if (_nearTargetSamples >= minNearSamples) {
      _settled = true;
      debugPrint(
        '[player-debug] startup_seek_verified currentSeconds=$currentSeconds targetSeconds=$targetSeconds retries=$_retryCount nearSamples=$_nearTargetSamples',
      );
      return;
    }

    if (elapsedMs >= maxWindowMs) {
      _settled = true;
      debugPrint(
        '[player-debug] startup_seek_give_up reason=window_timeout currentSeconds=$currentSeconds targetSeconds=$targetSeconds retries=$_retryCount',
      );
      return;
    }

    if (elapsedMs < retryDelayMs || _retryCount >= maxRetries) {
      return;
    }

    _retryCount++;
    debugPrint(
      '[player-debug] startup_seek_retry attempt=$_retryCount currentSeconds=$currentSeconds targetSeconds=$targetSeconds',
    );
    unawaited(_seek(target));
  }
}
