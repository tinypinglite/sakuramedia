import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:sakuramedia/core/json/dto_json_codec.dart';

part 'activity_notification_dto.g.dart';

@JsonSerializable(converters: dtoJsonConverters, createToJson: false)
@CopyWith()
class ActivityNotificationDto {
  const ActivityNotificationDto({
    required this.id,
    required this.category,
    required this.title,
    required this.content,
    required this.eventType,
    required this.dedupeKey,
    required this.resourceType,
    required this.resourceId,
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
  final String? eventType;
  final String? dedupeKey;
  final String? resourceType;
  final int? resourceId;
  final bool isRead;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final int? relatedTaskRunId;
  final String? relatedResourceType;
  final int? relatedResourceId;

  ActivityNotificationDto mergeFromServer(ActivityNotificationDto next) {
    return copyWith(
      category: next.category,
      title: next.title,
      content: next.content,
      eventType: next.eventType,
      dedupeKey: next.dedupeKey,
      resourceType: next.resourceType,
      resourceId: next.resourceId,
      isRead: next.isRead,
      createdAt: next.createdAt,
      updatedAt: next.updatedAt,
      relatedTaskRunId: next.relatedTaskRunId,
      relatedResourceType: next.relatedResourceType,
      relatedResourceId: next.relatedResourceId,
    );
  }

  factory ActivityNotificationDto.fromJson(Map<String, dynamic> json) =>
      _$ActivityNotificationDtoFromJson(json);

  _$ActivityNotificationDtoCWProxy get copyWith =>
      _$ActivityNotificationDtoCWProxyImpl(this);

  /// 值相等：轮询/已读回写用它判断是否实质变化，未变则跳过写回，
  /// 避免定时 tick 凭空重建订阅者。
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ActivityNotificationDto &&
        other.id == id &&
        other.category == category &&
        other.title == title &&
        other.content == content &&
        other.eventType == eventType &&
        other.dedupeKey == dedupeKey &&
        other.resourceType == resourceType &&
        other.resourceId == resourceId &&
        other.isRead == isRead &&
        other.createdAt == createdAt &&
        other.updatedAt == updatedAt &&
        other.relatedTaskRunId == relatedTaskRunId &&
        other.relatedResourceType == relatedResourceType &&
        other.relatedResourceId == relatedResourceId;
  }

  @override
  int get hashCode => Object.hash(
    id,
    category,
    title,
    content,
    eventType,
    dedupeKey,
    resourceType,
    resourceId,
    isRead,
    createdAt,
    updatedAt,
    relatedTaskRunId,
    relatedResourceType,
    relatedResourceId,
  );
}
