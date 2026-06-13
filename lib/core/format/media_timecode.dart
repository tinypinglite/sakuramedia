String formatMediaTimecode(int seconds) {
  final duration = Duration(seconds: seconds);
  final hours = duration.inHours;
  final minutes = duration.inMinutes.remainder(60);
  final remainingSeconds = duration.inSeconds.remainder(60);
  if (hours > 0) {
    return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
  }
  return '${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
}

/// 以中文「X时Y分Z秒」形式描述时长，用于切片标题等可读场景。
///
/// 例：228 秒 → `3分48秒`；3661 秒 → `1时1分1秒`；45 秒 → `45秒`。
String formatMediaDurationLabel(int seconds) {
  final safeSeconds = seconds < 0 ? 0 : seconds;
  final duration = Duration(seconds: safeSeconds);
  final hours = duration.inHours;
  final minutes = duration.inMinutes.remainder(60);
  final remainingSeconds = duration.inSeconds.remainder(60);
  final buffer = StringBuffer();
  if (hours > 0) {
    buffer.write('$hours时');
  }
  if (hours > 0 || minutes > 0) {
    buffer.write('$minutes分');
  }
  buffer.write('$remainingSeconds秒');
  return buffer.toString();
}
