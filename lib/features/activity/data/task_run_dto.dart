import 'dart:convert';

import 'package:sakuramedia/core/json/json_parse.dart';
import 'package:sakuramedia/l10n/app_localizations.dart';

class TaskRunDto {
  const TaskRunDto({
    required this.id,
    required this.taskKey,
    required this.taskName,
    required this.triggerType,
    required this.state,
    required this.progressCurrent,
    required this.progressTotal,
    required this.progressText,
    required this.resultText,
    required this.resultSummary,
    required this.errorMessage,
    required this.startedAt,
    required this.finishedAt,
    required this.createdAt,
    required this.updatedAt,
    this.hasWarning = false,
  });

  final int id;
  final String taskKey;
  final String taskName;
  final String triggerType;
  final String state;
  final int? progressCurrent;
  final int? progressTotal;
  final String? progressText;
  final String? resultText;
  final Map<String, dynamic>? resultSummary;
  final String? errorMessage;
  final DateTime? startedAt;
  final DateTime? finishedAt;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  /// 后端在 `completed` 结果里带警告（如部分文件失败 / 跳过超阈值）时置位。
  /// 旧后端不下发该字段，解析为 `false`。
  final bool hasWarning;

  bool get isActive => state == 'pending' || state == 'running';

  /// 需要用户关注：失败，或完成但带警告。
  bool get needsAttention => state == 'failed' || hasWarning;

  bool get hasDeterminateProgress =>
      progressCurrent != null && progressTotal != null && progressTotal! > 0;
  double? get progressValue {
    if (!hasDeterminateProgress) {
      return null;
    }
    return (progressCurrent! / progressTotal!).clamp(0.0, 1.0);
  }

  /// `library_import` 任务里尚未解决的失败文件数（不含主动跳过项）；其他任务或无明细时为 0。
  ///
  /// 失败项在后端重试成功后会被标记为 `resolved`，任务中心轮询到新 summary 后
  /// 计数自然回落，处理入口随之消失。
  int get unresolvedFailedFileCount => _failedFileItems
      .where((item) => item['kind'] != 'skipped' && item['state'] != 'resolved')
      .length;

  /// `library_import` 任务里被主动跳过的文件数（如文件过小/格式不支持），仅信息展示。
  int get skippedFileCount =>
      _failedFileItems.where((item) => item['kind'] == 'skipped').length;

  Iterable<Map<String, dynamic>> get _failedFileItems sync* {
    if (taskKey != 'library_import') return;
    final failedFiles = resultSummary?['failed_files'];
    if (failedFiles is! List) return;
    for (final item in failedFiles) {
      final map = asMapOrNull(item);
      if (map != null) yield map;
    }
  }

  String? displaySummary(AppLocalizations l10n) {
    if (state == 'failed' &&
        errorMessage != null &&
        errorMessage!.trim().isNotEmpty) {
      return errorMessage;
    }
    final mediaTransferSummary = _mediaTransferSummary(l10n);
    if (mediaTransferSummary != null) {
      return mediaTransferSummary;
    }
    final batchOperationSummary = _batchOperationSummary(l10n);
    if (batchOperationSummary != null) {
      return batchOperationSummary;
    }
    if (resultText != null && resultText!.trim().isNotEmpty) {
      return resultText;
    }
    if (progressText != null && progressText!.trim().isNotEmpty) {
      return progressText;
    }
    return null;
  }

  /// `batch_operation` 任务完成后的「成功 X 项 · 失败 Y 项」摘要。
  String? _batchOperationSummary(AppLocalizations l10n) {
    if (taskKey != 'batch_operation' || resultSummary == null) {
      return null;
    }
    final succeeded = resultSummary!['succeeded_count'];
    final failed = resultSummary!['failed_count'];
    if (succeeded is! int || failed is! int) {
      return null;
    }
    final fragments = <String>[
      if (succeeded > 0) l10n.activitySummarySucceeded(succeeded),
      if (failed > 0) l10n.activitySummaryFailed(failed),
    ];
    return fragments.isEmpty ? null : fragments.join(' · ');
  }

  String? _mediaTransferSummary(AppLocalizations l10n) {
    if (taskKey != 'media_storage_transfer' || resultSummary == null) {
      return null;
    }
    final summary = resultSummary!;
    final fragments = <String>[];
    void addCount(String key, String Function(int count) label) {
      final value = summary[key];
      if (value is int && value > 0) fragments.add(label(value));
    }

    addCount('transferred_count', l10n.activitySummaryTransferred);
    addCount('skipped_count', l10n.activitySummarySkipped);
    addCount('failed_count', l10n.activitySummaryTransferFailed);
    addCount('cleanup_incomplete_count', l10n.activitySummaryCleanupIncomplete);
    final unexecuted = summary['unexecuted_media_ids'];
    if (unexecuted is List && unexecuted.isNotEmpty) {
      fragments.add(l10n.activitySummaryUnexecuted(unexecuted.length));
    }
    return fragments.isEmpty ? null : fragments.join(' · ');
  }

  TaskRunDto copyWith({
    String? taskKey,
    String? taskName,
    String? triggerType,
    String? state,
    Object? progressCurrent = _sentinel,
    Object? progressTotal = _sentinel,
    Object? progressText = _sentinel,
    Object? resultText = _sentinel,
    Object? resultSummary = _sentinel,
    Object? errorMessage = _sentinel,
    Object? startedAt = _sentinel,
    Object? finishedAt = _sentinel,
    Object? createdAt = _sentinel,
    Object? updatedAt = _sentinel,
    bool? hasWarning,
  }) {
    return TaskRunDto(
      id: id,
      taskKey: taskKey ?? this.taskKey,
      taskName: taskName ?? this.taskName,
      triggerType: triggerType ?? this.triggerType,
      state: state ?? this.state,
      progressCurrent: identical(progressCurrent, _sentinel)
          ? this.progressCurrent
          : progressCurrent as int?,
      progressTotal: identical(progressTotal, _sentinel)
          ? this.progressTotal
          : progressTotal as int?,
      progressText: identical(progressText, _sentinel)
          ? this.progressText
          : progressText as String?,
      resultText: identical(resultText, _sentinel)
          ? this.resultText
          : resultText as String?,
      resultSummary: identical(resultSummary, _sentinel)
          ? this.resultSummary
          : resultSummary as Map<String, dynamic>?,
      errorMessage: identical(errorMessage, _sentinel)
          ? this.errorMessage
          : errorMessage as String?,
      startedAt: identical(startedAt, _sentinel)
          ? this.startedAt
          : startedAt as DateTime?,
      finishedAt: identical(finishedAt, _sentinel)
          ? this.finishedAt
          : finishedAt as DateTime?,
      createdAt: identical(createdAt, _sentinel)
          ? this.createdAt
          : createdAt as DateTime?,
      updatedAt: identical(updatedAt, _sentinel)
          ? this.updatedAt
          : updatedAt as DateTime?,
      hasWarning: hasWarning ?? this.hasWarning,
    );
  }

  TaskRunDto mergeFromServer(TaskRunDto next) {
    return copyWith(
      taskKey: next.taskKey,
      taskName: next.taskName,
      triggerType: next.triggerType,
      state: next.state,
      progressCurrent: next.progressCurrent,
      progressTotal: next.progressTotal,
      progressText: next.progressText,
      resultText: next.resultText,
      resultSummary: next.resultSummary,
      errorMessage: next.errorMessage,
      startedAt: next.startedAt,
      finishedAt: next.finishedAt,
      createdAt: next.createdAt,
      updatedAt: next.updatedAt,
      hasWarning: next.hasWarning,
    );
  }

  factory TaskRunDto.fromJson(Map<String, dynamic> json) {
    return TaskRunDto(
      id: asInt(json['id']),
      taskKey: json['task_key'] as String? ?? '',
      taskName: json['task_name'] as String? ?? '',
      triggerType: json['trigger_type'] as String? ?? '',
      state: json['state'] as String? ?? '',
      progressCurrent: asIntOrNull(json['progress_current']),
      progressTotal: asIntOrNull(json['progress_total']),
      progressText: json['progress_text'] as String?,
      resultText: json['result_text'] as String?,
      resultSummary: asMapOrNull(json['result_summary']),
      errorMessage: json['error_message'] as String?,
      startedAt: asDateTime(json['started_at']),
      finishedAt: asDateTime(json['finished_at']),
      createdAt: asDateTime(json['created_at']),
      updatedAt: asDateTime(json['updated_at']),
      hasWarning: json['has_warning'] as bool? ?? false,
    );
  }

  /// 值相等：任务中心轮询拿它判断快照是否实质变化，未变则不写回 state，
  /// 避免 3 秒 tick 凭空重建订阅者。必须覆盖全部字段。
  ///
  /// [resultSummary] 只做 JSON 文本比对（同一次快照序列化稳定），避免深比较成本。
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is TaskRunDto &&
        other.id == id &&
        other.taskKey == taskKey &&
        other.taskName == taskName &&
        other.triggerType == triggerType &&
        other.state == state &&
        other.progressCurrent == progressCurrent &&
        other.progressTotal == progressTotal &&
        other.progressText == progressText &&
        other.resultText == resultText &&
        _jsonMapsEqual(other.resultSummary, resultSummary) &&
        other.errorMessage == errorMessage &&
        other.startedAt == startedAt &&
        other.finishedAt == finishedAt &&
        other.createdAt == createdAt &&
        other.updatedAt == updatedAt &&
        other.hasWarning == hasWarning;
  }

  @override
  int get hashCode => Object.hash(
    id,
    taskKey,
    state,
    progressCurrent,
    progressTotal,
    progressText,
    resultText,
    errorMessage,
    startedAt,
    finishedAt,
    createdAt,
    updatedAt,
    hasWarning,
  );
}

bool _jsonMapsEqual(Map<String, dynamic>? a, Map<String, dynamic>? b) {
  if (identical(a, b)) return true;
  if (a == null || b == null) return false;
  return jsonEncode(a) == jsonEncode(b);
}

const Object _sentinel = Object();
