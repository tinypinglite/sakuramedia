import 'package:sakuramedia/core/json/json_parse.dart';

/// 失败文件条目的处理状态，与后端 `failed_files[].state` 对齐。
enum ImportFailedItemState {
  /// 可再次发起人工匹配重试。
  pending,

  /// 已入队重试任务，等待执行结果。
  queued,

  /// 已通过重试导入成功。
  resolved;

  static ImportFailedItemState fromWire(String? value) {
    return switch (value) {
      'queued' => ImportFailedItemState.queued,
      'resolved' => ImportFailedItemState.resolved,
      _ => ImportFailedItemState.pending,
    };
  }
}

/// `GET /imports/{task_run_id}/failed-items` 的失败文件条目。
///
/// 只解析界面需要的字段；`source_ref`、`library_id` 等宿主内部字段由后端保留在
/// 任务 summary 中，不通过该资源接口暴露。
class ImportFailedItemDto {
  const ImportFailedItemDto({
    required this.id,
    required this.relativePath,
    required this.sizeBytes,
    required this.reason,
    required this.kind,
    required this.state,
    required this.lastRetryError,
    required this.canManualSearch,
  });

  final String id;
  final String relativePath;
  final int sizeBytes;
  final String reason;

  /// `file`（失败，可能可重试）或 `skipped`（主动跳过，仅信息展示）。
  final String kind;
  final ImportFailedItemState state;
  final String? lastRetryError;
  final bool canManualSearch;

  bool get isSkipped => kind == 'skipped';

  String get fileName => relativePath.split('/').last;

  factory ImportFailedItemDto.fromJson(Map<String, dynamic> json) {
    return ImportFailedItemDto(
      id: json['id'] as String? ?? '',
      relativePath: json['relative_path'] as String? ?? '',
      sizeBytes: asInt(json['size_bytes']),
      reason: json['reason'] as String? ?? '',
      kind: json['kind'] as String? ?? 'file',
      state: ImportFailedItemState.fromWire(json['state'] as String?),
      lastRetryError: asStringOrNull(json['last_retry_error'], trim: true),
      canManualSearch: json['can_manual_search'] == true,
    );
  }
}
