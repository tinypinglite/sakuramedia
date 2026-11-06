import 'package:intl/intl.dart';

final Map<String?, NumberFormat> _countFormatters = <String?, NumberFormat>{};
final Map<String?, NumberFormat> _compactCountFormatters =
    <String?, NumberFormat>{};
final Map<(String?, int), NumberFormat> _percentFormatters =
    <(String?, int), NumberFormat>{};

/// 千分位计数：`1286` → `1,286`。
String formatAppCount(int value, {String? locale}) {
  final formatter = _countFormatters.putIfAbsent(
    locale,
    () => NumberFormat.decimalPattern(locale),
  );
  return formatter.format(value);
}

/// 紧凑计数：`1286` → `1.3K`（跟随 [locale]）。
String formatAppCompactCount(num value, {String? locale}) {
  final formatter = _compactCountFormatters.putIfAbsent(
    locale,
    () => NumberFormat.compact(locale: locale),
  );
  return formatter.format(value);
}

/// 比例格式化：`0.049` → `4.9%`，小数位数由 [decimals] 控制。
String formatAppPercent(num fraction, {int decimals = 1, String? locale}) {
  final formatter = _percentFormatters.putIfAbsent(
    (locale, decimals),
    () => NumberFormat.decimalPercentPattern(
      locale: locale,
      decimalDigits: decimals,
    ),
  );
  return formatter.format(fraction);
}

/// 把字节数格式化为可读的 B / KB / MB / GB / TB。
///
/// 适用于需要全量级粒度的场景（如文件浏览）。影片媒体列表另有「只用
/// GB/MB」的专用显示契约，不要用本函数替换那些位置。
///
/// [maxDecimals] 控制非 B 单位的小数位上限；[trimTrailingZeros] 为 true 时
/// 去掉无意义的尾随 0（`1.0 KB` → `1 KB`）。
String formatFileSize(
  int bytes, {
  int maxDecimals = 1,
  bool trimTrailingZeros = true,
}) {
  assert(maxDecimals >= 0, 'maxDecimals must not be negative');
  if (bytes <= 0) {
    return '0 B';
  }
  const units = <String>['B', 'KB', 'MB', 'GB', 'TB'];
  var value = bytes.toDouble();
  var unitIndex = 0;
  while (value >= 1024 && unitIndex < units.length - 1) {
    value /= 1024;
    unitIndex += 1;
  }
  final text = unitIndex == 0
      ? value.toStringAsFixed(0)
      : _formatDecimal(
          value,
          decimals: maxDecimals,
          trimTrailingZeros: trimTrailingZeros,
        );
  return '$text ${units[unitIndex]}';
}

String _formatDecimal(
  double value, {
  required int decimals,
  required bool trimTrailingZeros,
}) {
  var text = value.toStringAsFixed(decimals);
  if (!trimTrailingZeros || !text.contains('.')) {
    return text;
  }
  text = text.replaceFirst(RegExp(r'0+$'), '');
  return text.replaceFirst(RegExp(r'\.$'), '');
}
