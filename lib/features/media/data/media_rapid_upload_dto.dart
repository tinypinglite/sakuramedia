import 'package:sakuramedia/core/json/json_parse.dart';

/// 秒传批次逐项终态。
///
/// - `pending` / `running`：尚未落最终态，本地文件保持原样。
/// - `succeeded`：云端登记 + 本地文件已删除。
/// - `failed`：秒传失败；本地记录与文件保持不变。
/// - `cleanupFailed`：云端已登记但本地文件未能安全删除；重试仅执行本地清理。
enum MediaRapidUploadItemState {
  pending,
  running,
  succeeded,
  failed,
  cleanupFailed,
  unknown,
}

extension MediaRapidUploadItemStateX on MediaRapidUploadItemState {
  bool get isTerminal => switch (this) {
    MediaRapidUploadItemState.succeeded => true,
    MediaRapidUploadItemState.failed => true,
    MediaRapidUploadItemState.cleanupFailed => true,
    _ => false,
  };

  bool get isRetryable => switch (this) {
    MediaRapidUploadItemState.failed => true,
    MediaRapidUploadItemState.cleanupFailed => true,
    _ => false,
  };

  String get label => switch (this) {
    MediaRapidUploadItemState.pending => '待处理',
    MediaRapidUploadItemState.running => '进行中',
    MediaRapidUploadItemState.succeeded => '已完成',
    MediaRapidUploadItemState.failed => '失败',
    MediaRapidUploadItemState.cleanupFailed => '云端已登记，本地未清理',
    MediaRapidUploadItemState.unknown => '未知状态',
  };

  static MediaRapidUploadItemState fromWire(dynamic value) => switch (value) {
    'pending' => MediaRapidUploadItemState.pending,
    'running' => MediaRapidUploadItemState.running,
    'succeeded' => MediaRapidUploadItemState.succeeded,
    'failed' => MediaRapidUploadItemState.failed,
    'cleanup_failed' => MediaRapidUploadItemState.cleanupFailed,
    _ => MediaRapidUploadItemState.unknown,
  };
}

/// 批次整体状态。
enum MediaRapidUploadBatchState {
  pending,
  running,
  completed,
  completedWithErrors,
  failed,
  unknown,
}

extension MediaRapidUploadBatchStateX on MediaRapidUploadBatchState {
  bool get isTerminal => switch (this) {
    MediaRapidUploadBatchState.completed => true,
    MediaRapidUploadBatchState.completedWithErrors => true,
    MediaRapidUploadBatchState.failed => true,
    _ => false,
  };

  bool get isRunning => switch (this) {
    MediaRapidUploadBatchState.pending => true,
    MediaRapidUploadBatchState.running => true,
    _ => false,
  };

  String get label => switch (this) {
    MediaRapidUploadBatchState.pending => '排队中',
    MediaRapidUploadBatchState.running => '进行中',
    MediaRapidUploadBatchState.completed => '全部成功',
    MediaRapidUploadBatchState.completedWithErrors => '部分完成',
    MediaRapidUploadBatchState.failed => '失败',
    MediaRapidUploadBatchState.unknown => '未知状态',
  };

  static MediaRapidUploadBatchState fromWire(dynamic value) => switch (value) {
    'pending' => MediaRapidUploadBatchState.pending,
    'running' => MediaRapidUploadBatchState.running,
    'completed' => MediaRapidUploadBatchState.completed,
    'completed_with_errors' => MediaRapidUploadBatchState.completedWithErrors,
    'failed' => MediaRapidUploadBatchState.failed,
    _ => MediaRapidUploadBatchState.unknown,
  };
}

/// `POST /media/rapid-uploads` 202 响应。
class MediaRapidUploadTriggerResponseDto {
  const MediaRapidUploadTriggerResponseDto({
    required this.batchId,
    required this.taskRunId,
    required this.status,
  });

  final int batchId;
  final int? taskRunId;
  final String status;

  factory MediaRapidUploadTriggerResponseDto.fromJson(
    Map<String, dynamic> json,
  ) {
    return MediaRapidUploadTriggerResponseDto(
      batchId: asInt(json['rapid_upload_batch_id']),
      taskRunId: asIntOrNull(json['task_run_id']),
      status: json['status'] as String? ?? '',
    );
  }
}

/// 批次列表项（无 items）。
class MediaRapidUploadBatchListItemDto {
  const MediaRapidUploadBatchListItemDto({
    required this.id,
    required this.targetLibraryId,
    this.retryOfBatchId,
    this.taskRunId,
    required this.state,
    required this.totalCount,
    required this.succeededCount,
    required this.failedCount,
    required this.cleanupFailedCount,
    this.startedAt,
    this.finishedAt,
    required this.createdAt,
    required this.updatedAt,
  });

  final int id;
  final int targetLibraryId;
  final int? retryOfBatchId;
  final int? taskRunId;
  final MediaRapidUploadBatchState state;
  final int totalCount;
  final int succeededCount;
  final int failedCount;
  final int cleanupFailedCount;
  final DateTime? startedAt;
  final DateTime? finishedAt;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  int get pendingCount {
    final done = succeededCount + failedCount + cleanupFailedCount;
    final remaining = totalCount - done;
    return remaining < 0 ? 0 : remaining;
  }

  bool get hasRetryable => failedCount > 0 || cleanupFailedCount > 0;

  factory MediaRapidUploadBatchListItemDto.fromJson(Map<String, dynamic> json) {
    return MediaRapidUploadBatchListItemDto(
      id: asInt(json['id']),
      targetLibraryId: asInt(json['target_library_id']),
      retryOfBatchId: asIntOrNull(json['retry_of_batch_id']),
      taskRunId: asIntOrNull(json['task_run_id']),
      state: MediaRapidUploadBatchStateX.fromWire(json['state']),
      totalCount: asInt(json['total_count']),
      succeededCount: asInt(json['succeeded_count']),
      failedCount: asInt(json['failed_count']),
      cleanupFailedCount: asInt(json['cleanup_failed_count']),
      startedAt: asDateTime(json['started_at']),
      finishedAt: asDateTime(json['finished_at']),
      createdAt: asDateTime(json['created_at']),
      updatedAt: asDateTime(json['updated_at']),
    );
  }
}

/// 批次详情单项。
class MediaRapidUploadItemDto {
  const MediaRapidUploadItemDto({
    required this.id,
    this.mediaId,
    required this.action,
    required this.state,
    required this.sourcePath,
    required this.sourceSizeBytes,
    this.sourceSha1,
    this.targetFid,
    this.targetPickcode,
    this.targetName,
    this.errorMessage,
    this.startedAt,
    this.finishedAt,
    this.createdAt,
    this.updatedAt,
  });

  final int id;
  final int? mediaId;
  final String action;
  final MediaRapidUploadItemState state;
  final String sourcePath;
  final int sourceSizeBytes;
  final String? sourceSha1;
  final String? targetFid;
  final String? targetPickcode;
  final String? targetName;
  final String? errorMessage;
  final DateTime? startedAt;
  final DateTime? finishedAt;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  factory MediaRapidUploadItemDto.fromJson(Map<String, dynamic> json) {
    return MediaRapidUploadItemDto(
      id: asInt(json['id']),
      mediaId: asIntOrNull(json['media_id']),
      action: json['action'] as String? ?? '',
      state: MediaRapidUploadItemStateX.fromWire(json['state']),
      sourcePath: json['source_path'] as String? ?? '',
      sourceSizeBytes: asInt(json['source_size_bytes']),
      sourceSha1: asStringOrNull(json['source_sha1'], trim: true),
      targetFid: asStringOrNull(json['target_fid'], trim: true),
      targetPickcode: asStringOrNull(json['target_pickcode'], trim: true),
      targetName: asStringOrNull(json['target_name'], trim: true),
      errorMessage: asStringOrNull(json['error_message'], trim: true),
      startedAt: asDateTime(json['started_at']),
      finishedAt: asDateTime(json['finished_at']),
      createdAt: asDateTime(json['created_at']),
      updatedAt: asDateTime(json['updated_at']),
    );
  }
}

/// 批次详情（含 items）。
class MediaRapidUploadBatchDto extends MediaRapidUploadBatchListItemDto {
  const MediaRapidUploadBatchDto({
    required super.id,
    required super.targetLibraryId,
    super.retryOfBatchId,
    super.taskRunId,
    required super.state,
    required super.totalCount,
    required super.succeededCount,
    required super.failedCount,
    required super.cleanupFailedCount,
    super.startedAt,
    super.finishedAt,
    required super.createdAt,
    required super.updatedAt,
    required this.items,
  });

  final List<MediaRapidUploadItemDto> items;

  factory MediaRapidUploadBatchDto.fromJson(Map<String, dynamic> json) {
    final base = MediaRapidUploadBatchListItemDto.fromJson(json);
    final rawItems = json['items'];
    final items =
        rawItems is List
            ? rawItems
                .map(asMapOrNull)
                .whereType<Map<String, dynamic>>()
                .map(MediaRapidUploadItemDto.fromJson)
                .toList(growable: false)
            : const <MediaRapidUploadItemDto>[];
    return MediaRapidUploadBatchDto(
      id: base.id,
      targetLibraryId: base.targetLibraryId,
      retryOfBatchId: base.retryOfBatchId,
      taskRunId: base.taskRunId,
      state: base.state,
      totalCount: base.totalCount,
      succeededCount: base.succeededCount,
      failedCount: base.failedCount,
      cleanupFailedCount: base.cleanupFailedCount,
      startedAt: base.startedAt,
      finishedAt: base.finishedAt,
      createdAt: base.createdAt,
      updatedAt: base.updatedAt,
      items: items,
    );
  }
}
