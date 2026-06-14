import 'package:sakuramedia/core/json/json_parse.dart';

class ResourceTaskStateCountsDto {
  const ResourceTaskStateCountsDto({
    required this.pending,
    required this.running,
    required this.succeeded,
    required this.failed,
  });

  static const ResourceTaskStateCountsDto empty = ResourceTaskStateCountsDto(
    pending: 0,
    running: 0,
    succeeded: 0,
    failed: 0,
  );

  final int pending;
  final int running;
  final int succeeded;
  final int failed;

  int get total => pending + running + succeeded + failed;

  factory ResourceTaskStateCountsDto.fromJson(Map<String, dynamic> json) {
    return ResourceTaskStateCountsDto(
      pending: asInt(json['pending']),
      running: asInt(json['running']),
      succeeded: asInt(json['succeeded']),
      failed: asInt(json['failed']),
    );
  }
}

class ResourceTaskDefinitionDto {
  const ResourceTaskDefinitionDto({
    required this.taskKey,
    required this.resourceType,
    required this.displayName,
    required this.defaultSort,
    required this.allowReset,
    required this.stateCounts,
  });

  final String taskKey;
  final String resourceType;
  final String displayName;
  final String? defaultSort;
  final bool allowReset;
  final ResourceTaskStateCountsDto stateCounts;

  factory ResourceTaskDefinitionDto.fromJson(Map<String, dynamic> json) {
    final rawCounts = json['state_counts'];
    return ResourceTaskDefinitionDto(
      taskKey: json['task_key'] as String? ?? '',
      resourceType: json['resource_type'] as String? ?? '',
      displayName: json['display_name'] as String? ?? '',
      defaultSort: asStringOrNull(json['default_sort'], trim: true),
      allowReset: json['allow_reset'] as bool? ?? false,
      stateCounts:
          rawCounts is Map
              ? ResourceTaskStateCountsDto.fromJson(
                rawCounts.map(
                  (dynamic key, dynamic value) =>
                      MapEntry(key.toString(), value),
                ),
              )
              : ResourceTaskStateCountsDto.empty,
    );
  }
}
