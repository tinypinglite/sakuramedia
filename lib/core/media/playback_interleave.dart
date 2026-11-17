import 'dart:math' as math;

/// 音视频交错异常的检测来源。
enum PlaybackInterleaveSource {
  /// 解析 MP4/MOV 的 moov 采样表，得到静态布局结论。
  mp4Layout,

  /// 播放过程中观察 Range 请求的远距离来回跳读。
  rangePattern,
}

/// 一次音视频交错异常的检测结果。
///
/// 代理是唯一的产生方，播放器页面只消费；不落盘、不跨播放会话保留。
class PlaybackInterleaveSignal {
  const PlaybackInterleaveSignal({
    required this.cacheKey,
    required this.source,
    required this.maxDistanceBytes,
    required this.spanBytes,
    this.ratio,
  });

  final String cacheKey;
  final PlaybackInterleaveSource source;

  /// 音视频数据在文件中的最大物理距离（字节）。
  final int maxDistanceBytes;

  /// 同一时间窗口内数据在文件中的总跨度（字节）。
  final int spanBytes;

  /// 跨度与窗口内实际读取字节数的比值，越小越接近正常交错。
  final double? ratio;

  int get effectiveDistanceBytes => math.max(maxDistanceBytes, spanBytes);
}
