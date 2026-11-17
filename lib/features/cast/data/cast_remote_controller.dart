import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:sakuramedia/core/media/media_playback_progress_controller.dart';
import 'package:sakuramedia/features/cast/data/cast_director.dart';
import 'package:sakuramedia/features/cast/data/cast_session.dart';
import 'package:sakuramedia/features/cast/data/cast_transport.dart';
import 'package:sakuramedia/l10n/app_localizations.dart';
import 'package:sakuramedia/l10n/app_localizations_zh.dart';

/// 遥控页面对的电视状态。
enum CastRemotePhase {
  /// 尚未拿到第一帧状态。
  connecting,

  /// 电视正在播放。
  playing,

  /// 电视已暂停。
  paused,

  /// 电视被停止（未播完，例如被电视遥控器操作）。
  stopped,

  /// 播放到结尾。
  finished,

  /// 连续轮询失败，与电视失联。
  disconnected,
}

@immutable
class CastRemoteState {
  const CastRemoteState({
    this.phase = CastRemotePhase.connecting,
    this.position = Duration.zero,
    this.duration = Duration.zero,
    this.isSeeking = false,
    this.errorMessage,
  });

  final CastRemotePhase phase;
  final Duration position;
  final Duration duration;

  /// 正在下发 seek（含防抖窗口）。
  final bool isSeeking;

  final String? errorMessage;

  bool get isPlaying => phase == CastRemotePhase.playing;

  /// 可正常下发播放/暂停控制的阶段。
  bool get isInteractive =>
      phase == CastRemotePhase.playing || phase == CastRemotePhase.paused;

  CastRemoteState copyWith({
    CastRemotePhase? phase,
    Duration? position,
    Duration? duration,
    bool? isSeeking,
    Object? errorMessage = _sentinel,
  }) {
    return CastRemoteState(
      phase: phase ?? this.phase,
      position: position ?? this.position,
      duration: duration ?? this.duration,
      isSeeking: isSeeking ?? this.isSeeking,
      errorMessage: identical(errorMessage, _sentinel)
          ? this.errorMessage
          : errorMessage as String?,
    );
  }
}

const Object _sentinel = Object();

/// 投屏遥控核心：轮询电视状态、统一 seek 出口、播放控制与进度回写。
///
/// 生命周期跟随遥控页（页面创建/销毁），会话信息由外层的
/// `castSessionControllerProvider` 保留。
class CastRemoteController extends ChangeNotifier {
  CastRemoteController({
    required this.session,
    required this._transport,
    required Future<void> Function({
      required int mediaId,
      required int positionSeconds,
    })
    reportProgress,
    this._pollInterval = const Duration(seconds: 2),
    this._seekDebounce = const Duration(milliseconds: 250),
    this._seekCooldown = const Duration(milliseconds: 1500),
    Duration progressReportInterval = const Duration(seconds: 5),
    AppLocalizations Function()? l10n,
  }) : _l10n = l10n {
    _state = CastRemoteState(
      duration: Duration(seconds: session.durationSeconds),
    );
    _progress = MediaPlaybackProgressController(
      reportProgress: reportProgress,
      resolveMediaId: () => session.mediaId,
      shouldDeferReport: () => false,
      reportInterval: progressReportInterval,
    );
  }

  static const int _maxConsecutiveFailures = 3;

  /// 距结尾小于该阈值且状态为 STOPPED 时视为播放结束。
  static const Duration _finishedThreshold = Duration(seconds: 2);

  final CastSession session;
  final CastTransport _transport;
  final Duration _pollInterval;
  final Duration _seekDebounce;
  final Duration _seekCooldown;
  final AppLocalizations Function()? _l10n;
  late final MediaPlaybackProgressController _progress;

  AppLocalizations get _localizations => _l10n?.call() ?? AppLocalizationsZh();

  late CastRemoteState _state;

  CastRemoteState get state => _state;

  Timer? _pollTimer;
  Timer? _seekDebounceTimer;
  Timer? _followUpPollTimer;
  int _failureCount = 0;
  bool _pollInFlight = false;
  Duration? _pendingSeekTarget;
  DateTime? _resumePositionAt;
  bool _disposed = false;

  /// 开始/恢复轮询：立即拉一次状态，之后按周期刷新。
  void start() {
    if (_disposed) return;
    _pollTimer?.cancel();
    unawaited(_poll());
    _pollTimer = Timer.periodic(_pollInterval, (_) => unawaited(_poll()));
  }

  /// 暂停轮询（退出遥控页时调用；会话由外层保留）。
  void stopPolling() {
    _pollTimer?.cancel();
    _pollTimer = null;
    _followUpPollTimer?.cancel();
    _followUpPollTimer = null;
  }

  /// 统一跳转出口：快进快退、拖动进度条、点击缩略图都走这里。
  ///
  /// 立即乐观更新位置；防抖窗口内的连续调用合并为最终目标。
  Future<void> seekTo(Duration target) async {
    if (_disposed) return;
    final clamped = _clampToDuration(target);
    _pendingSeekTarget = clamped;
    _emit(
      _state.copyWith(
        position: clamped,
        isSeeking: true,
        errorMessage: null,
      ),
    );
    _seekDebounceTimer?.cancel();
    _seekDebounceTimer = Timer(
      _seekDebounce,
      () => unawaited(_flushPendingSeek()),
    );
  }

  /// 相对跳转（快退传负值）。
  Future<void> seekBy(Duration delta) => seekTo(_state.position + delta);

  Future<void> play() async {
    if (_disposed || !_state.isInteractive) return;
    _emit(_state.copyWith(phase: CastRemotePhase.playing, errorMessage: null));
    await _runControl(_transport.play);
  }

  Future<void> pause() async {
    if (_disposed || !_state.isInteractive) return;
    _emit(_state.copyWith(phase: CastRemotePhase.paused, errorMessage: null));
    await _runControl(_transport.pause);
  }

  /// 断开投屏：停止电视播放并尽力回写最终进度。
  Future<void> stopPlayback() async {
    stopPolling();
    _seekDebounceTimer?.cancel();
    _pendingSeekTarget = null;
    try {
      await _transport.stop();
    } catch (_) {
      // 停止失败不阻塞会话清理。
    }
    await _progress.flush();
  }

  /// 断开态下手动重试一次。
  Future<void> retry() async {
    if (_disposed) return;
    _failureCount = 0;
    _emit(_state.copyWith(phase: CastRemotePhase.connecting));
    await _poll();
  }

  /// 电视被停止或播放结束后，从头重新播放。
  Future<void> restartFromBeginning() async {
    if (_disposed) return;
    _emit(
      _state.copyWith(
        phase: CastRemotePhase.playing,
        position: Duration.zero,
        errorMessage: null,
      ),
    );
    try {
      await _transport.seek(Duration.zero);
      await _transport.play();
      _resumePositionAt = DateTime.now().add(_seekCooldown);
    } catch (error) {
      if (_disposed) return;
      _emit(
        _state.copyWith(
          errorMessage: castErrorMessage(
            error,
            l10n: _localizations,
            fallback: _localizations.castRestartFailed,
          ),
        ),
      );
      unawaited(_poll());
    }
  }

  @override
  void dispose() {
    _disposed = true;
    stopPolling();
    _seekDebounceTimer?.cancel();
    unawaited(_progress.flush());
    _progress.dispose();
    super.dispose();
  }

  Future<void> _runControl(Future<void> Function() action) async {
    try {
      await action();
    } catch (error) {
      if (_disposed) return;
      _emit(
        _state.copyWith(
          errorMessage: castErrorMessage(
            error,
            l10n: _localizations,
            fallback: _localizations.castControlFailed,
          ),
        ),
      );
      // 尽快让轮询校正乐观状态。
      unawaited(_poll());
      return;
    }
    // 控制成功后延迟校正一次，避免电视状态切换期间按钮闪回。
    _followUpPollTimer?.cancel();
    _followUpPollTimer = Timer(const Duration(milliseconds: 600), () {
      if (!_disposed) {
        unawaited(_poll());
      }
    });
  }

  Future<void> _flushPendingSeek() async {
    final target = _pendingSeekTarget;
    _pendingSeekTarget = null;
    if (target == null || _disposed) return;
    try {
      await _transport.seek(target);
      if (_disposed) return;
      // 冷却期内忽略电视回报的旧位置，防止进度条闪回；同时把位置钉锚到
      // seek 目标，避免防抖窗口内被并发轮询覆盖后无法回正。
      _resumePositionAt = DateTime.now().add(_seekCooldown);
      _emit(_state.copyWith(position: target, isSeeking: false));
      _progress.handlePlaybackPosition(target);
      unawaited(_progress.flush());
    } catch (error) {
      if (_disposed) return;
      _emit(
        _state.copyWith(
          isSeeking: false,
          errorMessage: castErrorMessage(
            error,
            l10n: _localizations,
            fallback: _localizations.castSeekFailed,
          ),
        ),
      );
    }
  }

  Future<void> _poll() async {
    if (_disposed || _pollInFlight) return;
    _pollInFlight = true;
    try {
      final results = await Future.wait<Object>([
        _transport.positionInfo(),
        _transport.playbackStatus(),
      ]);
      if (_disposed) return;
      _failureCount = 0;
      _handlePollResult(
        results[0] as CastPositionInfo,
        results[1] as CastPlaybackStatus,
      );
    } catch (_) {
      if (_disposed) return;
      _failureCount += 1;
      if (_failureCount >= _maxConsecutiveFailures) {
        _emit(_state.copyWith(phase: CastRemotePhase.disconnected));
      }
    } finally {
      _pollInFlight = false;
    }
  }

  void _handlePollResult(CastPositionInfo info, CastPlaybackStatus status) {
    final duration = _resolveDuration(info.duration);
    final resumeAt = _resumePositionAt;
    // 防抖窗口（待定 seek）与冷却期都忽略电视回报的位置，保留乐观值。
    final ignoringPosition =
        _pendingSeekTarget != null ||
        (resumeAt != null && DateTime.now().isBefore(resumeAt));
    if (resumeAt != null && !ignoringPosition) {
      _resumePositionAt = null;
    }
    final position = ignoringPosition
        ? _state.position
        : _clampToDuration(info.position, duration: duration);

    _progress.handlePlaybackPosition(position);
    _progress.handlePlaybackPlayingChanged(
      status == CastPlaybackStatus.playing,
    );

    _emit(
      _state.copyWith(
        phase: _resolvePhase(status, position, duration),
        position: position,
        duration: duration,
      ),
    );
  }

  Duration _resolveDuration(Duration? reported) {
    if (session.durationSeconds > 0) {
      return Duration(seconds: session.durationSeconds);
    }
    return reported ?? _state.duration;
  }

  Duration _clampToDuration(Duration value, {Duration? duration}) {
    final limit = duration ?? _state.duration;
    if (value < Duration.zero) {
      return Duration.zero;
    }
    if (limit > Duration.zero && value > limit) {
      return limit;
    }
    return value;
  }

  CastRemotePhase _resolvePhase(
    CastPlaybackStatus status,
    Duration position,
    Duration duration,
  ) {
    return switch (status) {
      CastPlaybackStatus.playing => CastRemotePhase.playing,
      CastPlaybackStatus.paused => CastRemotePhase.paused,
      CastPlaybackStatus.transitioning =>
        _state.isInteractive ? _state.phase : CastRemotePhase.playing,
      CastPlaybackStatus.stopped =>
        duration > Duration.zero && position + _finishedThreshold >= duration
            ? CastRemotePhase.finished
            : CastRemotePhase.stopped,
      CastPlaybackStatus.unknown => _state.phase,
    };
  }

  void _emit(CastRemoteState next) {
    if (_disposed) return;
    _state = next;
    notifyListeners();
  }
}
