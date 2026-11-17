class CatalogSearchStreamStatus {
  const CatalogSearchStreamStatus({
    required this.message,
    required this.isRunning,
    required this.isFailure,
    this.current,
    this.total,
    this.statsLabel,
  });

  final String message;
  final bool isRunning;
  final bool isFailure;
  final int? current;
  final int? total;

  /// 统计摘要文案；由 provider 按当前语言渲染后写入。
  final String? statsLabel;

  String? get progressLabel {
    if (current == null || total == null) {
      return null;
    }
    return '$current / $total';
  }
}
