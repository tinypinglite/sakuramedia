import 'dart:async';

typedef ReportMediaPlaybackProgress =
    Future<void> Function({required int mediaId, required int positionSeconds});

/// 跨影片/视频播放器共用的播放进度生命周期。
///
/// 业务页面保留自己的媒体加载、恢复提示和错误状态；本类只处理播放位置、
/// 播放状态、定时上报以及离开页面前的 flush。
class MediaPlaybackProgressController {
  MediaPlaybackProgressController({
    required this.reportProgress,
    required this.resolveMediaId,
    required this.shouldDeferReport,
    this.reportInterval = const Duration(seconds: 5),
  });

  final ReportMediaPlaybackProgress reportProgress;
  final int? Function() resolveMediaId;
  final bool Function() shouldDeferReport;
  final Duration reportInterval;

  Timer? _progressTimer;
  bool _isDisposed = false;
  bool _isPlaying = false;
  int _currentPlaybackSeconds = 0;
  int? _lastReportedPositionSeconds;

  int get currentPlaybackSeconds => _currentPlaybackSeconds;

  void reset({
    int currentPlaybackSeconds = 0,
    int? lastReportedPositionSeconds,
  }) {
    if (_isDisposed) return;
    _stopTimer();
    _isPlaying = false;
    _currentPlaybackSeconds = currentPlaybackSeconds;
    _lastReportedPositionSeconds = lastReportedPositionSeconds;
  }

  void setCurrentPlaybackSeconds(int seconds) {
    if (_isDisposed) return;
    _currentPlaybackSeconds = seconds;
  }

  void handlePlaybackPosition(Duration position) {
    if (_isDisposed) return;
    _currentPlaybackSeconds = position.inSeconds;
  }

  void handlePlaybackPlayingChanged(bool isPlaying) {
    if (_isDisposed || _isPlaying == isPlaying) return;
    _isPlaying = isPlaying;
    if (isPlaying) {
      _startTimer();
    } else {
      _stopTimer();
    }
  }

  Future<void> flush() => _reportProgressIfNeeded();

  void dispose() {
    _isDisposed = true;
    _stopTimer();
  }

  void _startTimer() {
    _stopTimer();
    _progressTimer = Timer.periodic(reportInterval, (_) {
      unawaited(_reportProgressIfNeeded());
    });
  }

  void _stopTimer() {
    _progressTimer?.cancel();
    _progressTimer = null;
  }

  Future<void> _reportProgressIfNeeded() async {
    if (_isDisposed || shouldDeferReport()) return;
    final mediaId = resolveMediaId();
    final positionSeconds = _currentPlaybackSeconds;
    if (mediaId == null ||
        positionSeconds <= 0 ||
        positionSeconds == _lastReportedPositionSeconds) {
      return;
    }
    _lastReportedPositionSeconds = positionSeconds;
    try {
      await reportProgress(mediaId: mediaId, positionSeconds: positionSeconds);
    } catch (_) {
      _lastReportedPositionSeconds = null;
    }
  }
}
