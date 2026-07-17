/// 根据媒体记录判断是否值得提示续播。
///
/// 开头十秒内的记录通常没有恢复价值；距离结尾不足三十秒的记录按已看完处理，
/// 避免每次重播都弹出一个几乎位于片尾的位置。
Duration? resolvePlaybackResumePosition({
  required int storedPositionSeconds,
  required int durationSeconds,
  Duration minimumPosition = const Duration(seconds: 10),
  Duration minimumRemaining = const Duration(seconds: 30),
}) {
  if (storedPositionSeconds <= minimumPosition.inSeconds) {
    return null;
  }
  if (durationSeconds > 0 &&
      durationSeconds - storedPositionSeconds <= minimumRemaining.inSeconds) {
    return null;
  }
  return Duration(seconds: storedPositionSeconds);
}
