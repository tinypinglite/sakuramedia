import 'package:sakuramedia/core/json/json_parse.dart';

class ActivityNotificationDto {
  const ActivityNotificationDto({
    required this.id,
    required this.category,
    required this.title,
    required this.content,
    required this.isRead,
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
      createdAt: next.createdAt,
      updatedAt: next.updatedAt,
      relatedTaskRunId: next.relatedTaskRunId,
      relatedResourceType: next.relatedResourceType,
      relatedResourceId: next.relatedResourceId,
    );
  }

  factory ActivityNotificationDto.fromJson(Map<String, dynamic> json) {
    return ActivityNotificationDto(
      id: asInt(json['id']),
      category: json['category'] as String? ?? '',
      title: json['title'] as String? ?? '',
      content: json['content'] as String? ?? '',
      isRead: json['is_read'] as bool? ?? false,
      createdAt: asDateTime(json['created_at']),
      updatedAt: asDateTime(json['updated_at']),
      relatedTaskRunId: asIntOrNull(json['related_task_run_id']),
      relatedResourceType: json['related_resource_type'] as String?,
      relatedResourceId: asIntOrNull(json['related_resource_id']),
    );
  }
}

const Object _sentinel = Object();
