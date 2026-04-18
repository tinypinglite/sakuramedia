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
      pending: _toInt(json['pending']),
      running: _toInt(json['running']),
      succeeded: _toInt(json['succeeded']),
      failed: _toInt(json['failed']),
    );
  }

  static int _toInt(dynamic value) {
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    if (value is String) {
      return int.tryParse(value) ?? 0;
    }
    return 0;
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
      defaultSort: _trimmedStringOrNull(json['default_sort']),
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

  static String? _trimmedStringOrNull(dynamic value) {
    if (value is! String) {
      return null;
    }
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }
}
