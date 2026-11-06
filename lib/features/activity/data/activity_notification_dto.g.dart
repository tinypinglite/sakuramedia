// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'activity_notification_dto.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$ActivityNotificationDtoCWProxy {
  ActivityNotificationDto id(int id);

  ActivityNotificationDto category(String category);

  ActivityNotificationDto title(String title);

  ActivityNotificationDto content(String content);

  ActivityNotificationDto eventType(String? eventType);

  ActivityNotificationDto dedupeKey(String? dedupeKey);

  ActivityNotificationDto resourceType(String? resourceType);

  ActivityNotificationDto resourceId(int? resourceId);

  ActivityNotificationDto isRead(bool isRead);

  ActivityNotificationDto createdAt(DateTime? createdAt);

  ActivityNotificationDto updatedAt(DateTime? updatedAt);

  ActivityNotificationDto relatedTaskRunId(int? relatedTaskRunId);

  ActivityNotificationDto relatedResourceType(String? relatedResourceType);

  ActivityNotificationDto relatedResourceId(int? relatedResourceId);

  /// Creates a new instance with the provided field values.
  /// Omitted fields keep their values; explicit `null` clears nullable fields.
  /// The public API rejects `null` for non-nullable fields. To update a single field use `ActivityNotificationDto(...).copyWith.fieldName(value)`.
  ///
  /// Example:
  /// ```dart
  /// ActivityNotificationDto(...).copyWith(id: 12, name: "My name")
  /// ```
  ActivityNotificationDto call({
    int id,
    String category,
    String title,
    String content,
    String? eventType,
    String? dedupeKey,
    String? resourceType,
    int? resourceId,
    bool isRead,
    DateTime? createdAt,
    DateTime? updatedAt,
    int? relatedTaskRunId,
    String? relatedResourceType,
    int? relatedResourceId,
  });
}

/// Callable proxy for `copyWith` functionality.
/// Use as `instanceOfActivityNotificationDto.copyWith(...)` or call `instanceOfActivityNotificationDto.copyWith.fieldName(value)` for a single field.
class _$ActivityNotificationDtoCWProxyImpl
    implements _$ActivityNotificationDtoCWProxy {
  const _$ActivityNotificationDtoCWProxyImpl(this._value);

  final ActivityNotificationDto _value;

  @override
  ActivityNotificationDto id(int id) => call(id: id);

  @override
  ActivityNotificationDto category(String category) => call(category: category);

  @override
  ActivityNotificationDto title(String title) => call(title: title);

  @override
  ActivityNotificationDto content(String content) => call(content: content);

  @override
  ActivityNotificationDto eventType(String? eventType) =>
      call(eventType: eventType);

  @override
  ActivityNotificationDto dedupeKey(String? dedupeKey) =>
      call(dedupeKey: dedupeKey);

  @override
  ActivityNotificationDto resourceType(String? resourceType) =>
      call(resourceType: resourceType);

  @override
  ActivityNotificationDto resourceId(int? resourceId) =>
      call(resourceId: resourceId);

  @override
  ActivityNotificationDto isRead(bool isRead) => call(isRead: isRead);

  @override
  ActivityNotificationDto createdAt(DateTime? createdAt) =>
      call(createdAt: createdAt);

  @override
  ActivityNotificationDto updatedAt(DateTime? updatedAt) =>
      call(updatedAt: updatedAt);

  @override
  ActivityNotificationDto relatedTaskRunId(int? relatedTaskRunId) =>
      call(relatedTaskRunId: relatedTaskRunId);

  @override
  ActivityNotificationDto relatedResourceType(String? relatedResourceType) =>
      call(relatedResourceType: relatedResourceType);

  @override
  ActivityNotificationDto relatedResourceId(int? relatedResourceId) =>
      call(relatedResourceId: relatedResourceId);

  /// Creates a new instance with the provided field values.
  /// Omitted fields keep their values; explicit `null` clears nullable fields.
  /// The public API rejects `null` for non-nullable fields. To update a single field use `ActivityNotificationDto(...).copyWith.fieldName(value)`.
  ///
  /// Example:
  /// ```dart
  /// ActivityNotificationDto(...).copyWith(id: 12, name: "My name")
  /// ```
  @override
  ActivityNotificationDto call({
    Object? id = const $CopyWithPlaceholder(),
    Object? category = const $CopyWithPlaceholder(),
    Object? title = const $CopyWithPlaceholder(),
    Object? content = const $CopyWithPlaceholder(),
    Object? eventType = const $CopyWithPlaceholder(),
    Object? dedupeKey = const $CopyWithPlaceholder(),
    Object? resourceType = const $CopyWithPlaceholder(),
    Object? resourceId = const $CopyWithPlaceholder(),
    Object? isRead = const $CopyWithPlaceholder(),
    Object? createdAt = const $CopyWithPlaceholder(),
    Object? updatedAt = const $CopyWithPlaceholder(),
    Object? relatedTaskRunId = const $CopyWithPlaceholder(),
    Object? relatedResourceType = const $CopyWithPlaceholder(),
    Object? relatedResourceId = const $CopyWithPlaceholder(),
  }) {
    return ActivityNotificationDto(
      id: id == const $CopyWithPlaceholder() || id == null
          ? _value.id
          // ignore: cast_nullable_to_non_nullable
          : id as int,
      category: category == const $CopyWithPlaceholder() || category == null
          ? _value.category
          // ignore: cast_nullable_to_non_nullable
          : category as String,
      title: title == const $CopyWithPlaceholder() || title == null
          ? _value.title
          // ignore: cast_nullable_to_non_nullable
          : title as String,
      content: content == const $CopyWithPlaceholder() || content == null
          ? _value.content
          // ignore: cast_nullable_to_non_nullable
          : content as String,
      eventType: eventType == const $CopyWithPlaceholder()
          ? _value.eventType
          // ignore: cast_nullable_to_non_nullable
          : eventType as String?,
      dedupeKey: dedupeKey == const $CopyWithPlaceholder()
          ? _value.dedupeKey
          // ignore: cast_nullable_to_non_nullable
          : dedupeKey as String?,
      resourceType: resourceType == const $CopyWithPlaceholder()
          ? _value.resourceType
          // ignore: cast_nullable_to_non_nullable
          : resourceType as String?,
      resourceId: resourceId == const $CopyWithPlaceholder()
          ? _value.resourceId
          // ignore: cast_nullable_to_non_nullable
          : resourceId as int?,
      isRead: isRead == const $CopyWithPlaceholder() || isRead == null
          ? _value.isRead
          // ignore: cast_nullable_to_non_nullable
          : isRead as bool,
      createdAt: createdAt == const $CopyWithPlaceholder()
          ? _value.createdAt
          // ignore: cast_nullable_to_non_nullable
          : createdAt as DateTime?,
      updatedAt: updatedAt == const $CopyWithPlaceholder()
          ? _value.updatedAt
          // ignore: cast_nullable_to_non_nullable
          : updatedAt as DateTime?,
      relatedTaskRunId: relatedTaskRunId == const $CopyWithPlaceholder()
          ? _value.relatedTaskRunId
          // ignore: cast_nullable_to_non_nullable
          : relatedTaskRunId as int?,
      relatedResourceType: relatedResourceType == const $CopyWithPlaceholder()
          ? _value.relatedResourceType
          // ignore: cast_nullable_to_non_nullable
          : relatedResourceType as String?,
      relatedResourceId: relatedResourceId == const $CopyWithPlaceholder()
          ? _value.relatedResourceId
          // ignore: cast_nullable_to_non_nullable
          : relatedResourceId as int?,
    );
  }
}

extension $ActivityNotificationDtoCopyWith on ActivityNotificationDto {
  /// Returns a callable class used to build a new instance with modified fields.
  /// Example: `instanceOfActivityNotificationDto.copyWith(...)` or `instanceOfActivityNotificationDto.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$ActivityNotificationDtoCWProxy get copyWith =>
      _$ActivityNotificationDtoCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ActivityNotificationDto _$ActivityNotificationDtoFromJson(
  Map<String, dynamic> json,
) => ActivityNotificationDto(
  id: const IntJsonConverter().fromJson(json['id']),
  category: const StringJsonConverter().fromJson(json['category']),
  title: const StringJsonConverter().fromJson(json['title']),
  content: const StringJsonConverter().fromJson(json['content']),
  eventType: const NullableStringJsonConverter().fromJson(json['event_type']),
  dedupeKey: const NullableStringJsonConverter().fromJson(json['dedupe_key']),
  resourceType: const NullableStringJsonConverter().fromJson(
    json['resource_type'],
  ),
  resourceId: const NullableIntJsonConverter().fromJson(json['resource_id']),
  isRead: const BoolJsonConverter().fromJson(json['is_read']),
  createdAt: const DateTimeJsonConverter().fromJson(json['created_at']),
  updatedAt: const DateTimeJsonConverter().fromJson(json['updated_at']),
  relatedTaskRunId: const NullableIntJsonConverter().fromJson(
    json['related_task_run_id'],
  ),
  relatedResourceType: const NullableStringJsonConverter().fromJson(
    json['related_resource_type'],
  ),
  relatedResourceId: const NullableIntJsonConverter().fromJson(
    json['related_resource_id'],
  ),
);
