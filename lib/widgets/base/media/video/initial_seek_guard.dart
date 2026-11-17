import 'dart:async';

/// 等播放器越过“已解析出时长/已输出首帧，但网络预读仍在收尾”的初始化窗口。
///
/// media_kit 没有单独的 ready-to-seek 事件，因此用三个可观测信号组合判断：首帧已
/// 输出、播放器没有 buffering、播放位置已实际向前推进一小段。超时只作兜底，避免
/// 异常媒体永久锁住控制层。
Future<void> waitUntilInitialSeekReady({
  required Future<void> firstFrame,
  required Stream<Duration> positionStream,
  required Duration Function() currentPosition,
  required bool Function() isPlaying,
  required bool Function() isBuffering,
  Duration requiredPlaybackProgress = const Duration(milliseconds: 500),
  Duration firstFrameTimeout = const Duration(seconds: 10),
  Duration stabilizationTimeout = const Duration(seconds: 2),
}) async {
  try {
    await firstFrame.timeout(firstFrameTimeout);
  } catch (_) {
    return;
  }

  final baseline = currentPosition();
  final ready = Completer<void>();
  StreamSubscription<Duration>? subscription;
  Timer? timer;

  void complete() {
    if (!ready.isCompleted) {
      ready.complete();
    }
  }

  subscription = positionStream.listen(
    (position) {
      final progressed = position - baseline >= requiredPlaybackProgress;
      if (progressed && isPlaying() && !isBuffering()) {
        complete();
      }
    },
    onError: (_, __) => complete(),
    onDone: complete,
  );
  timer = Timer(stabilizationTimeout, complete);

  try {
    await ready.future;
  } finally {
    timer.cancel();
    await subscription.cancel();
  }
}
