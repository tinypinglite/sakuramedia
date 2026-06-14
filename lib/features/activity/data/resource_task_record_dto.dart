import 'package:sakuramedia/core/json/json_parse.dart';

class ResourceTaskResourceSummaryDto {
  const ResourceTaskResourceSummaryDto({
    required this.resourceId,
    required this.movieNumber,
    required this.title,
    required this.path,
    required this.valid,
  });

  final int resourceId;
  final String? movieNumber;
  final String? title;
  final String? path;
  final bool? valid;

  factory ResourceTaskResourceSummaryDto.fromJson(Map<String, dynamic> json) {
    return ResourceTaskResourceSummaryDto(
      resourceId: asInt(json['resource_id']),
      movieNumber: _stringOrNull(json['movie_number']),
      title: _stringOrNull(json['title']),
      path: _stringOrNull(json['path']),
      valid: json['valid'] as bool?,
    );
  }

  static String? _stringOrNull(dynamic value) {
    if (value is! String) {
      return null;
    }
    return value.isEmpty ? null : value;
  }
}

class ResourceTaskRecordDto {
  const ResourceTaskRecordDto({
    required this.taskKey,
    required this.resourceType,
    required this.resourceId,
    required this.state,
    required this.attemptCount,
    required this.lastAttemptedAt,
    required this.lastSucceededAt,
    required this.lastError,
    required this.lastErrorAt,
    required this.lastTaskRunId,
    required this.lastTriggerType,
    required this.createdAt,
    required this.updatedAt,
    required this.resource,
  });

  final String taskKey;
  final String resourceType;
  final int resourceId;
  final String state;
  final int attemptCount;
  final DateTime? lastAttemptedAt;
  final DateTime? lastSucceededAt;
  final String? lastError;
  final DateTime? lastErrorAt;
  final int? lastTaskRunId;
  final String? lastTriggerType;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final ResourceTaskResourceSummaryDto? resource;

  bool get isFailed => state == 'failed';
  bool get isRunning => state == 'running';
  bool get isPending => state == 'pending';
  bool get isSucceeded => state == 'succeeded';

  String get recordKey => '$taskKey/$resourceId';

  factory ResourceTaskRecordDto.fromJson(Map<String, dynamic> json) {
    final rawResource = json['resource'];
    return ResourceTaskRecordDto(
      taskKey: json['task_key'] as String? ?? '',
      resourceType: json['resource_type'] as String? ?? '',
      resourceId: asInt(json['resource_id']),
      state: json['state'] as String? ?? '',
      attemptCount: asInt(json['attempt_count']),
      lastAttemptedAt: asDateTime(json['last_attempted_at']),
      lastSucceededAt: asDateTime(json['last_succeeded_at']),
      lastError: _stringOrNull(json['last_error']),
      lastErrorAt: asDateTime(json['last_error_at']),
      lastTaskRunId: asIntOrNull(json['last_task_run_id']),
      lastTriggerType: _stringOrNull(json['last_trigger_type']),
      createdAt: asDateTime(json['created_at']),
      updatedAt: asDateTime(json['updated_at']),
      resource:
          rawResource is Map
              ? ResourceTaskResourceSummaryDto.fromJson(
                rawResource.map(
                  (dynamic key, dynamic value) =>
                      MapEntry(key.toString(), value),
                ),
              )
              : null,
    );
  }

  static String? _stringOrNull(dynamic value) {
    if (value is! String) {
      return null;
    }
    return value.isEmpty ? null : value;
  }
}
