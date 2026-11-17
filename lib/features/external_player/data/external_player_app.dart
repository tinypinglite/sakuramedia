/// 系统中可处理“播放视频”的外部播放器条目。
class ExternalPlayerApp {
  const ExternalPlayerApp({required this.id, required this.label});

  /// 平台提供的播放器唯一标识。
  ///
  /// Android 为应用包名，macOS 与 Windows 为应用程序路径。
  final String id;

  /// 用户可读的应用名称（来自系统）。
  final String label;

  static ExternalPlayerApp? fromMap(Map<Object?, Object?> map) {
    final id = map['id'];
    if (id is! String || id.isEmpty) {
      return null;
    }
    final label = map['label'];
    return ExternalPlayerApp(
      id: id,
      label: label is String && label.isNotEmpty ? label : id,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is ExternalPlayerApp && other.id == id && other.label == label;

  @override
  int get hashCode => Object.hash(id, label);
}
