/// 把字节数格式化为可读的 B / KB / MB / GB / TB。
///
/// 适用于需要全量级粒度的场景（如文件浏览）。影片媒体列表另有「只用
/// GB/MB」的专用显示契约，不要用本函数替换那些位置。
String formatFileSize(int bytes) {
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
  final text =
      unitIndex == 0 ? value.toStringAsFixed(0) : value.toStringAsFixed(1);
  return '$text ${units[unitIndex]}';
}
