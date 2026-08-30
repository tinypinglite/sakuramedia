/// Provider-owned opaque source reference selected from the browse response.
class MediaImportSource {
  const MediaImportSource({required this.sourceRef});

  final Map<String, dynamic> sourceRef;

  Map<String, dynamic> toJson() => <String, dynamic>{'source_ref': sourceRef};
}

/// How the storage provider should handle the source after a successful import.
enum SourceDisposition { keep, deleteAfterCommit }

extension SourceDispositionX on SourceDisposition {
  String get wireValue => switch (this) {
    SourceDisposition.keep => 'keep',
    SourceDisposition.deleteAfterCommit => 'delete_after_commit',
  };

  String get label => switch (this) {
    SourceDisposition.keep => '保留源文件',
    SourceDisposition.deleteAfterCommit => '导入成功后删除源文件',
  };
}
