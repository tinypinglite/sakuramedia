/// 媒体技术信息的统一展示格式。
///
/// 只负责把原始探测字段转成用户可读文本；缺失或无效值返回 `null`，
/// 由调用方决定是否省略该项。
String? formatVideoCodecName(String? codecName) {
  final normalized = codecName?.trim().toLowerCase();
  if (normalized == null || normalized.isEmpty) {
    return null;
  }
  switch (normalized) {
    case 'h264':
    case 'avc':
      return 'H.264';
    case 'h265':
    case 'hevc':
      return 'H.265';
    default:
      return normalized.replaceAll('_', '-').toUpperCase();
  }
}

String? formatVideoBitRate(int? videoBitRate, int? containerBitRate) {
  final bitRate = videoBitRate != null && videoBitRate > 0
      ? videoBitRate
      : containerBitRate;
  if (bitRate == null || bitRate <= 0) {
    return null;
  }
  return '${(bitRate / 1000000).toStringAsFixed(1)} Mbps';
}

String? formatVideoFrameRate(double? frameRate) {
  if (frameRate == null || frameRate <= 0) {
    return null;
  }
  if ((frameRate - frameRate.roundToDouble()).abs() < 0.001) {
    return '${frameRate.round()} fps';
  }
  final formatted = frameRate
      .toStringAsFixed(2)
      .replaceFirst(RegExp(r'0+$'), '')
      .replaceFirst(RegExp(r'\.$'), '');
  return '$formatted fps';
}

String? formatInterleaveGapSize(double? gapMib) {
  if (gapMib == null || gapMib <= 0) {
    return null;
  }
  return gapMib >= 1024
      ? '${(gapMib / 1024).toStringAsFixed(1)} GiB'
      : '${gapMib >= 100 ? gapMib.toStringAsFixed(0) : gapMib.toStringAsFixed(1)} MiB';
}
