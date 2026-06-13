/// 系统中可处理“播放视频”的外部播放器条目。
class ExternalPlayerApp {
  const ExternalPlayerApp({required this.packageName, required this.label});

  /// Android 应用包名，作为唯一标识与显式拉起目标。
  final String packageName;

  /// 用户可读的应用名称（来自系统）。
  final String label;

  static ExternalPlayerApp? fromMap(Map<Object?, Object?> map) {
    final packageName = map['packageName'];
    if (packageName is! String || packageName.isEmpty) {
      return null;
    }
    final label = map['label'];
    return ExternalPlayerApp(
      packageName: packageName,
      label: label is String && label.isNotEmpty ? label : packageName,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is ExternalPlayerApp &&
      other.packageName == packageName &&
      other.label == label;

  @override
  int get hashCode => Object.hash(packageName, label);
}
