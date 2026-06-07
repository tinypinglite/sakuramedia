/// 导入方式：`auto` 硬链接优先，`cleanup-source` 复制后删除源文件。
enum TransferMode { auto, cleanupSource }

extension TransferModeX on TransferMode {
  /// 后端序列化值。
  String get wireValue =>
      this == TransferMode.cleanupSource ? 'cleanup-source' : 'auto';

  String get label =>
      this == TransferMode.cleanupSource ? '复制后删除源文件' : '硬链接优先（保留源文件）';

  static TransferMode fromWire(dynamic value) =>
      value == 'cleanup-source' ? TransferMode.cleanupSource : TransferMode.auto;
}

/// 失败文件条目分类，决定其是否可被删除/重命名/重导。
enum FailedFileKind { file, skipped, warning, job }

FailedFileKind _parseFailedFileKind(dynamic value) {
  switch (value) {
    case 'skipped':
      return FailedFileKind.skipped;
    case 'warning':
      return FailedFileKind.warning;
    case 'job':
      return FailedFileKind.job;
    default:
      return FailedFileKind.file;
  }
}

/// 单条失败文件记录。
class FailedFileDto {
  const FailedFileDto({
    required this.path,
    required this.reason,
    required this.detail,
    required this.kind,
  });

  final String path;
  final String reason;
  final String detail;
  final FailedFileKind kind;

  /// 仅 `file` 类型可重导/删除/重命名。
  bool get isActionable => kind == FailedFileKind.file;

  factory FailedFileDto.fromJson(Map<String, dynamic> json) {
    return FailedFileDto(
      path: json['path'] as String? ?? '',
      reason: json['reason'] as String? ?? '',
      detail: json['detail'] as String? ?? '',
      kind: _parseFailedFileKind(json['kind']),
    );
  }
}

/// 导入作业列表项。
class ImportJobListItemDto {
  const ImportJobListItemDto({
    required this.id,
    required this.sourcePath,
    required this.libraryId,
    required this.downloadTaskId,
    required this.taskRunId,
    required this.state,
    required this.transferMode,
    required this.importedCount,
    required this.skippedCount,
    required this.failedCount,
    required this.startedAt,
    required this.finishedAt,
    required this.createdAt,
    required this.updatedAt,
  });

  final int id;
  final String sourcePath;
  final int libraryId;
  final int? downloadTaskId;
  final int? taskRunId;
  final String state;
  final TransferMode transferMode;
  final int importedCount;
  final int skippedCount;
  final int failedCount;
  final DateTime? startedAt;
  final DateTime? finishedAt;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  /// 终态（completed / failed）才允许失败文件的删除/重命名/重导。
  bool get isTerminal => state == 'completed' || state == 'failed';

  factory ImportJobListItemDto.fromJson(Map<String, dynamic> json) {
    return ImportJobListItemDto(
      id: _toInt(json['id']),
      sourcePath: json['source_path'] as String? ?? '',
      libraryId: _toInt(json['library_id']),
      downloadTaskId: _tryInt(json['download_task_id']),
      taskRunId: _tryInt(json['task_run_id']),
      state: json['state'] as String? ?? '',
      transferMode: TransferModeX.fromWire(json['transfer_mode']),
      importedCount: _toInt(json['imported_count']),
      skippedCount: _toInt(json['skipped_count']),
      failedCount: _toInt(json['failed_count']),
      startedAt: _parseDateTime(json['started_at']),
      finishedAt: _parseDateTime(json['finished_at']),
      createdAt: _parseDateTime(json['created_at']),
      updatedAt: _parseDateTime(json['updated_at']),
    );
  }

  static int _toInt(dynamic value) => _tryInt(value) ?? 0;

  static int? _tryInt(dynamic value) {
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    if (value is String) {
      return int.tryParse(value);
    }
    return null;
  }

  static DateTime? _parseDateTime(dynamic value) {
    if (value is! String || value.trim().isEmpty) {
      return null;
    }
    return DateTime.tryParse(value);
  }
}

/// 导入作业详情（含失败文件清单）。
class ImportJobDto extends ImportJobListItemDto {
  const ImportJobDto({
    required super.id,
    required super.sourcePath,
    required super.libraryId,
    required super.downloadTaskId,
    required super.taskRunId,
    required super.state,
    required super.transferMode,
    required super.importedCount,
    required super.skippedCount,
    required super.failedCount,
    required super.startedAt,
    required super.finishedAt,
    required super.createdAt,
    required super.updatedAt,
    required this.failedFiles,
  });

  final List<FailedFileDto> failedFiles;

  /// 可操作（可重导/删除/重命名）的失败文件。
  List<FailedFileDto> get actionableFailedFiles =>
      failedFiles.where((file) => file.isActionable).toList(growable: false);

  factory ImportJobDto.fromJson(Map<String, dynamic> json) {
    final base = ImportJobListItemDto.fromJson(json);
    final rawFiles = json['failed_files'];
    final failedFiles =
        rawFiles is List
            ? rawFiles
                .whereType<Map>()
                .map(
                  (item) => FailedFileDto.fromJson(
                    item.map(
                      (dynamic key, dynamic value) =>
                          MapEntry(key.toString(), value),
                    ),
                  ),
                )
                .toList(growable: false)
            : const <FailedFileDto>[];

    return ImportJobDto(
      id: base.id,
      sourcePath: base.sourcePath,
      libraryId: base.libraryId,
      downloadTaskId: base.downloadTaskId,
      taskRunId: base.taskRunId,
      state: base.state,
      transferMode: base.transferMode,
      importedCount: base.importedCount,
      skippedCount: base.skippedCount,
      failedCount: base.failedCount,
      startedAt: base.startedAt,
      finishedAt: base.finishedAt,
      createdAt: base.createdAt,
      updatedAt: base.updatedAt,
      failedFiles: failedFiles,
    );
  }
}

/// 触发导入 / 重导失败文件的响应（202）。
class ImportJobTriggerResponseDto {
  const ImportJobTriggerResponseDto({
    required this.importJobId,
    required this.taskRunId,
    required this.status,
  });

  final int importJobId;
  final int taskRunId;
  final String status;

  factory ImportJobTriggerResponseDto.fromJson(Map<String, dynamic> json) {
    return ImportJobTriggerResponseDto(
      importJobId: ImportJobListItemDto._toInt(json['import_job_id']),
      taskRunId: ImportJobListItemDto._toInt(json['task_run_id']),
      status: json['status'] as String? ?? '',
    );
  }
}
