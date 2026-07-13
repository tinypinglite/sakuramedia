sealed class MediaImportSource {
  const MediaImportSource();

  const factory MediaImportSource.local(String path) = LocalMediaImportSource;
  const factory MediaImportSource.cloud115(String cid) =
      Cloud115MediaImportSource;

  Map<String, dynamic> toJson();
}

class LocalMediaImportSource extends MediaImportSource {
  const LocalMediaImportSource(this.path);

  final String path;

  /// 序列化时兜底剪空白，防止调用方从用户输入直接构造带前后空格/换行的路径。
  @override
  Map<String, dynamic> toJson() =>
      <String, dynamic>{'source_path': path.trim()};

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
