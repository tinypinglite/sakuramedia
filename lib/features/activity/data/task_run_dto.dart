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

  bool get isActive => state == 'pending' || state == 'running';
  bool get isFinished => state == 'completed' || state == 'failed';
  bool get hasDeterminateProgress =>
      progressCurrent != null && progressTotal != null && progressTotal! > 0;
  double? get progressValue {
    if (!hasDeterminateProgress) {
      return null;
    }
    return (progressCurrent! / progressTotal!).clamp(0.0, 1.0);
  }

  String? get displaySummary {
    if (state == 'failed' &&
        errorMessage != null &&
        errorMessage!.trim().isNotEmpty) {
      return errorMessage;
    }
    if (resultText != null && resultText!.trim().isNotEmpty) {
      return resultText;
    }
    if (progressText != null && progressText!.trim().isNotEmpty) {
      return progressText;
    }
    return null;
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
  }) {
    return TaskRunDto(
      id: id,
      taskKey: taskKey ?? this.taskKey,
      taskName: taskName ?? this.taskName,
      triggerType: triggerType ?? this.triggerType,
      state: state ?? this.state,
      progressCurrent:
          identical(progressCurrent, _sentinel)
              ? this.progressCurrent
              : progressCurrent as int?,
      progressTotal:
          identical(progressTotal, _sentinel)
              ? this.progressTotal
              : progressTotal as int?,
      progressText:
          identical(progressText, _sentinel)
              ? this.progressText
              : progressText as String?,
      resultText:
          identical(resultText, _sentinel)
              ? this.resultText
              : resultText as String?,
      resultSummary:
          identical(resultSummary, _sentinel)
              ? this.resultSummary
              : resultSummary as Map<String, dynamic>?,
      errorMessage:
          identical(errorMessage, _sentinel)
              ? this.errorMessage
              : errorMessage as String?,
      startedAt:
          identical(startedAt, _sentinel)
              ? this.startedAt
              : startedAt as DateTime?,
      finishedAt:
          identical(finishedAt, _sentinel)
              ? this.finishedAt
              : finishedAt as DateTime?,
      createdAt:
          identical(createdAt, _sentinel)
              ? this.createdAt
              : createdAt as DateTime?,
      updatedAt:
          identical(updatedAt, _sentinel)
              ? this.updatedAt
              : updatedAt as DateTime?,
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
    );
  }

  factory TaskRunDto.fromJson(Map<String, dynamic> json) {
    return TaskRunDto(
      id: _toInt(json['id']),
      taskKey: json['task_key'] as String? ?? '',
      taskName: json['task_name'] as String? ?? '',
      triggerType: json['trigger_type'] as String? ?? '',
      state: json['state'] as String? ?? '',
      progressCurrent: _tryInt(json['progress_current']),
      progressTotal: _tryInt(json['progress_total']),
      progressText: json['progress_text'] as String?,
      resultText: json['result_text'] as String?,
      resultSummary: _toLooseMap(json['result_summary']),
      errorMessage: json['error_message'] as String?,
      startedAt: _parseDateTime(json['started_at']),
      finishedAt: _parseDateTime(json['finished_at']),
      createdAt: _parseDateTime(json['created_at']),
      updatedAt: _parseDateTime(json['updated_at']),
    );
  }

  static Map<String, dynamic>? _toLooseMap(dynamic value) {
    if (value is Map<String, dynamic>) {
      return value;
    }
    if (value is Map) {
      return value.map(
        (dynamic key, dynamic data) => MapEntry(key.toString(), data),
      );
    }
    return null;
  }

  static DateTime? _parseDateTime(dynamic value) {
    if (value is! String || value.trim().isEmpty) {
      return null;
    }
    return DateTime.tryParse(value);
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
}

const Object _sentinel = Object();
