class ActivityNotificationDto {
  const ActivityNotificationDto({
    required this.id,
    required this.category,
    required this.title,
    required this.content,
    required this.isRead,
    required this.archived,
    required this.createdAt,
    required this.updatedAt,
    required this.relatedTaskRunId,
    required this.relatedResourceType,
    required this.relatedResourceId,
  });

  final int id;
  final String category;
  final String title;
  final String content;
  final bool isRead;
  final bool archived;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final int? relatedTaskRunId;
  final String? relatedResourceType;
  final int? relatedResourceId;

  ActivityNotificationDto copyWith({
    String? category,
    String? title,
    String? content,
    bool? isRead,
    bool? archived,
    DateTime? createdAt,
    DateTime? updatedAt,
    Object? relatedTaskRunId = _sentinel,
    Object? relatedResourceType = _sentinel,
    Object? relatedResourceId = _sentinel,
  }) {
    return ActivityNotificationDto(
      id: id,
      category: category ?? this.category,
      title: title ?? this.title,
      content: content ?? this.content,
      isRead: isRead ?? this.isRead,
      archived: archived ?? this.archived,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      relatedTaskRunId:
          identical(relatedTaskRunId, _sentinel)
              ? this.relatedTaskRunId
              : relatedTaskRunId as int?,
      relatedResourceType:
          identical(relatedResourceType, _sentinel)
              ? this.relatedResourceType
              : relatedResourceType as String?,
      relatedResourceId:
          identical(relatedResourceId, _sentinel)
              ? this.relatedResourceId
              : relatedResourceId as int?,
    );
  }

  ActivityNotificationDto mergeFromServer(ActivityNotificationDto next) {
    return copyWith(
      category: next.category,
      title: next.title,
      content: next.content,
      isRead: next.isRead,
      archived: next.archived,
      createdAt: next.createdAt,
      updatedAt: next.updatedAt,
      relatedTaskRunId: next.relatedTaskRunId,
      relatedResourceType: next.relatedResourceType,
      relatedResourceId: next.relatedResourceId,
    );
  }

  factory ActivityNotificationDto.fromJson(Map<String, dynamic> json) {
    return ActivityNotificationDto(
      id: _toInt(json['id']),
      category: json['category'] as String? ?? '',
      title: json['title'] as String? ?? '',
      content: json['content'] as String? ?? '',
      isRead: json['is_read'] as bool? ?? false,
      archived: json['archived'] as bool? ?? false,
      createdAt: _parseDateTime(json['created_at']),
      updatedAt: _parseDateTime(json['updated_at']),
      relatedTaskRunId: _tryInt(json['related_task_run_id']),
      relatedResourceType: json['related_resource_type'] as String?,
      relatedResourceId: _tryInt(json['related_resource_id']),
    );
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
