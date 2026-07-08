import 'package:sakuramedia/core/json/json_parse.dart';
import 'package:sakuramedia/features/media_import/data/import_job_dto.dart';

export 'package:sakuramedia/features/media_import/data/import_job_dto.dart'
    show TransferMode, TransferModeX, FailedFileDto, FailedFileKind;

/// 视频（PornBox）导入作业列表项。
///
/// 与 JAV [ImportJobListItemDto] 同构，差异：无 `downloadTaskId`、有 `collectionId`。
class VideoImportJobListItemDto implements ImportJobCardData {
  const VideoImportJobListItemDto({
    required this.id,
    required this.sourcePath,
    required this.libraryId,
    required this.collectionId,
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

  @override
  final int id;
  @override
  final String sourcePath;
  final int libraryId;
  final int? collectionId;
  @override
  final int? taskRunId;
  @override
  final String state;
  @override
  final TransferMode transferMode;
  @override
  final int importedCount;
  @override
  final int skippedCount;
  @override
  final int failedCount;
  final DateTime? startedAt;
  @override
  final DateTime? finishedAt;
  @override
  final DateTime? createdAt;
  final DateTime? updatedAt;

  /// 终态（completed / failed）才允许失败文件的删除/重命名/重导。
  @override
  bool get isTerminal => state == 'completed' || state == 'failed';

  factory VideoImportJobListItemDto.fromJson(Map<String, dynamic> json) {
    return VideoImportJobListItemDto(
      id: asInt(json['id']),
      sourcePath: json['source_path'] as String? ?? '',
      libraryId: asInt(json['library_id']),
      collectionId: asIntOrNull(json['collection_id']),
      taskRunId: asIntOrNull(json['task_run_id']),
      state: json['state'] as String? ?? '',
      transferMode: TransferModeX.fromWire(json['transfer_mode']),
      importedCount: asInt(json['imported_count']),
      skippedCount: asInt(json['skipped_count']),
      failedCount: asInt(json['failed_count']),
      startedAt: asDateTime(json['started_at']),
      finishedAt: asDateTime(json['finished_at']),
      createdAt: asDateTime(json['created_at']),
      updatedAt: asDateTime(json['updated_at']),
    );
  }
}

/// 视频导入作业详情（含失败文件清单）。
class VideoImportJobDto extends VideoImportJobListItemDto
    implements ImportJobCardDetailData {
  const VideoImportJobDto({
    required super.id,
    required super.sourcePath,
    required super.libraryId,
    required super.collectionId,
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

  @override
  final List<FailedFileDto> failedFiles;

  /// 可操作（可重导/删除/重命名）的失败文件。
  @override
  List<FailedFileDto> get actionableFailedFiles =>
      failedFiles.where((file) => file.isActionable).toList(growable: false);

  factory VideoImportJobDto.fromJson(Map<String, dynamic> json) {
    final base = VideoImportJobListItemDto.fromJson(json);
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

    return VideoImportJobDto(
      id: base.id,
      sourcePath: base.sourcePath,
      libraryId: base.libraryId,
      collectionId: base.collectionId,
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

/// 触发视频导入 / 重导失败文件的响应（202）。
class VideoImportTriggerResponseDto {
  const VideoImportTriggerResponseDto({
    required this.videoImportJobId,
    required this.taskRunId,
    required this.status,
  });

  final int videoImportJobId;
  final int taskRunId;
  final String status;

  factory VideoImportTriggerResponseDto.fromJson(Map<String, dynamic> json) {
    return VideoImportTriggerResponseDto(
      videoImportJobId: asInt(json['video_import_job_id']),
      taskRunId: asInt(json['task_run_id']),
      status: json['status'] as String? ?? '',
    );
  }
}
