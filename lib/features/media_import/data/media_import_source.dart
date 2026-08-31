sealed class MediaImportSource {
  const MediaImportSource();

  const factory MediaImportSource.local(String path) = LocalMediaImportSource;
  const factory MediaImportSource.cloud115(String cid) =
      Cloud115MediaImportSource;
  const factory MediaImportSource.cloud115File(String fid) =
      Cloud115FileMediaImportSource;

  Map<String, dynamic> toJson();

  String get backend => switch (this) {
    LocalMediaImportSource() => 'local',
    Cloud115MediaImportSource() || Cloud115FileMediaImportSource() => 'cloud115',
  };
}

/// 后端统一导入接口支持的传输策略。
enum TransferMode { auto, cleanupSource }

extension TransferModeX on TransferMode {
  String get wireValue => switch (this) {
    TransferMode.auto => 'auto',
    TransferMode.cleanupSource => 'cleanup-source',
  };

  String get label => switch (this) {
    TransferMode.auto => '自动选择（保留源文件）',
    TransferMode.cleanupSource => '导入后清理源文件',
  };
}

class LocalMediaImportSource extends MediaImportSource {
  const LocalMediaImportSource(this.path);

  final String path;

  /// 序列化时兜底剪空白，防止调用方从用户输入直接构造带前后空格/换行的路径。
  @override
  Map<String, dynamic> toJson() => <String, dynamic>{
    'source_path': path.trim(),
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LocalMediaImportSource && other.path == path;

  @override
  int get hashCode => Object.hash('local', path);
}

class Cloud115MediaImportSource extends MediaImportSource {
  const Cloud115MediaImportSource(this.cid);

  final String cid;

  @override
  Map<String, dynamic> toJson() => <String, dynamic>{'source_cid': cid};

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Cloud115MediaImportSource && other.cid == cid;

  @override
  int get hashCode => Object.hash('cloud115', cid);
}

class Cloud115FileMediaImportSource extends MediaImportSource {
  const Cloud115FileMediaImportSource(this.fid);

  final String fid;

  @override
  Map<String, dynamic> toJson() => <String, dynamic>{'source_fid': fid};

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Cloud115FileMediaImportSource && other.fid == fid;

  @override
  int get hashCode => Object.hash('cloud115-file', fid);
}
