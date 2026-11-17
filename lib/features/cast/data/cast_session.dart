import 'package:sakuramedia/features/cast/data/cast_device.dart';

/// 一次进行中的投屏会话：目标设备 + 正在投送的媒体信息。
class CastSession {
  const CastSession({
    required this.device,
    required this.mediaId,
    required this.movieNumber,
    required this.durationSeconds,
  });

  final CastDevice device;
  final int mediaId;
  final String movieNumber;

  /// 影片本地数据里的时长；电视上报不可靠时用作兜底。
  final int durationSeconds;
}
