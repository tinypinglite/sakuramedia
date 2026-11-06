// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'task_run_dto.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$TaskRunDtoCWProxy {
  TaskRunDto id(int id);

  TaskRunDto taskKey(String taskKey);

  TaskRunDto taskName(String taskName);

  TaskRunDto triggerType(String triggerType);

  TaskRunDto state(String state);

  TaskRunDto progressCurrent(int? progressCurrent);

  TaskRunDto progressTotal(int? progressTotal);

  TaskRunDto progressText(String? progressText);

  TaskRunDto resultText(String? resultText);

  TaskRunDto resultSummary(Map<String, dynamic>? resultSummary);

  TaskRunDto errorMessage(String? errorMessage);

  TaskRunDto startedAt(DateTime? startedAt);

  TaskRunDto finishedAt(DateTime? finishedAt);

  TaskRunDto createdAt(DateTime? createdAt);

  TaskRunDto updatedAt(DateTime? updatedAt);

  TaskRunDto hasWarning(bool hasWarning);

  /// Creates a new instance with the provided field values.
  /// Omitted fields keep their values; explicit `null` clears nullable fields.
  /// The public API rejects `null` for non-nullable fields. To update a single field use `TaskRunDto(...).copyWith.fieldName(value)`.
  ///
  /// Example:
  /// ```dart
  /// TaskRunDto(...).copyWith(id: 12, name: "My name")
  /// ```
  TaskRunDto call({
    int id,
    String taskKey,
    String taskName,
    String triggerType,
    String state,
    int? progressCurrent,
    int? progressTotal,
    String? progressText,
    String? resultText,
    Map<String, dynamic>? resultSummary,
    String? errorMessage,
    DateTime? startedAt,
    DateTime? finishedAt,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool hasWarning,
  });
}

/// Callable proxy for `copyWith` functionality.
/// Use as `instanceOfTaskRunDto.copyWith(...)` or call `instanceOfTaskRunDto.copyWith.fieldName(value)` for a single field.
class _$TaskRunDtoCWProxyImpl implements _$TaskRunDtoCWProxy {
  const _$TaskRunDtoCWProxyImpl(this._value);

  final TaskRunDto _value;

  @override
  TaskRunDto id(int id) => call(id: id);

  @override
  TaskRunDto taskKey(String taskKey) => call(taskKey: taskKey);

  @override
  TaskRunDto taskName(String taskName) => call(taskName: taskName);

  @override
  TaskRunDto triggerType(String triggerType) => call(triggerType: triggerType);

  @override
  TaskRunDto state(String state) => call(state: state);

  @override
  TaskRunDto progressCurrent(int? progressCurrent) =>
      call(progressCurrent: progressCurrent);

  @override
  TaskRunDto progressTotal(int? progressTotal) =>
      call(progressTotal: progressTotal);

  @override
  TaskRunDto progressText(String? progressText) =>
      call(progressText: progressText);

  @override
  TaskRunDto resultText(String? resultText) => call(resultText: resultText);

  @override
  TaskRunDto resultSummary(Map<String, dynamic>? resultSummary) =>
      call(resultSummary: resultSummary);

  @override
  TaskRunDto errorMessage(String? errorMessage) =>
      call(errorMessage: errorMessage);

  @override
  TaskRunDto startedAt(DateTime? startedAt) => call(startedAt: startedAt);

  @override
  TaskRunDto finishedAt(DateTime? finishedAt) => call(finishedAt: finishedAt);

  @override
  TaskRunDto createdAt(DateTime? createdAt) => call(createdAt: createdAt);

  @override
  TaskRunDto updatedAt(DateTime? updatedAt) => call(updatedAt: updatedAt);

  @override
  TaskRunDto hasWarning(bool hasWarning) => call(hasWarning: hasWarning);

  /// Creates a new instance with the provided field values.
  /// Omitted fields keep their values; explicit `null` clears nullable fields.
  /// The public API rejects `null` for non-nullable fields. To update a single field use `TaskRunDto(...).copyWith.fieldName(value)`.
  ///
  /// Example:
  /// ```dart
  /// TaskRunDto(...).copyWith(id: 12, name: "My name")
  /// ```
  @override
  TaskRunDto call({
    Object? id = const $CopyWithPlaceholder(),
    Object? taskKey = const $CopyWithPlaceholder(),
    Object? taskName = const $CopyWithPlaceholder(),
    Object? triggerType = const $CopyWithPlaceholder(),
    Object? state = const $CopyWithPlaceholder(),
    Object? progressCurrent = const $CopyWithPlaceholder(),
    Object? progressTotal = const $CopyWithPlaceholder(),
    Object? progressText = const $CopyWithPlaceholder(),
    Object? resultText = const $CopyWithPlaceholder(),
    Object? resultSummary = const $CopyWithPlaceholder(),
    Object? errorMessage = const $CopyWithPlaceholder(),
    Object? startedAt = const $CopyWithPlaceholder(),
    Object? finishedAt = const $CopyWithPlaceholder(),
    Object? createdAt = const $CopyWithPlaceholder(),
    Object? updatedAt = const $CopyWithPlaceholder(),
    Object? hasWarning = const $CopyWithPlaceholder(),
  }) {
    return TaskRunDto(
      id: id == const $CopyWithPlaceholder() || id == null
          ? _value.id
          // ignore: cast_nullable_to_non_nullable
          : id as int,
      taskKey: taskKey == const $CopyWithPlaceholder() || taskKey == null
          ? _value.taskKey
          // ignore: cast_nullable_to_non_nullable
          : taskKey as String,
      taskName: taskName == const $CopyWithPlaceholder() || taskName == null
          ? _value.taskName
          // ignore: cast_nullable_to_non_nullable
          : taskName as String,
      triggerType:
          triggerType == const $CopyWithPlaceholder() || triggerType == null
          ? _value.triggerType
          // ignore: cast_nullable_to_non_nullable
          : triggerType as String,
      state: state == const $CopyWithPlaceholder() || state == null
          ? _value.state
          // ignore: cast_nullable_to_non_nullable
          : state as String,
      progressCurrent: progressCurrent == const $CopyWithPlaceholder()
          ? _value.progressCurrent
          // ignore: cast_nullable_to_non_nullable
          : progressCurrent as int?,
      progressTotal: progressTotal == const $CopyWithPlaceholder()
          ? _value.progressTotal
          // ignore: cast_nullable_to_non_nullable
          : progressTotal as int?,
      progressText: progressText == const $CopyWithPlaceholder()
          ? _value.progressText
          // ignore: cast_nullable_to_non_nullable
          : progressText as String?,
      resultText: resultText == const $CopyWithPlaceholder()
          ? _value.resultText
          // ignore: cast_nullable_to_non_nullable
          : resultText as String?,
      resultSummary: resultSummary == const $CopyWithPlaceholder()
          ? _value.resultSummary
          // ignore: cast_nullable_to_non_nullable
          : resultSummary as Map<String, dynamic>?,
      errorMessage: errorMessage == const $CopyWithPlaceholder()
          ? _value.errorMessage
          // ignore: cast_nullable_to_non_nullable
          : errorMessage as String?,
      startedAt: startedAt == const $CopyWithPlaceholder()
          ? _value.startedAt
          // ignore: cast_nullable_to_non_nullable
          : startedAt as DateTime?,
      finishedAt: finishedAt == const $CopyWithPlaceholder()
          ? _value.finishedAt
          // ignore: cast_nullable_to_non_nullable
          : finishedAt as DateTime?,
      createdAt: createdAt == const $CopyWithPlaceholder()
          ? _value.createdAt
          // ignore: cast_nullable_to_non_nullable
          : createdAt as DateTime?,
      updatedAt: updatedAt == const $CopyWithPlaceholder()
          ? _value.updatedAt
          // ignore: cast_nullable_to_non_nullable
          : updatedAt as DateTime?,
      hasWarning:
          hasWarning == const $CopyWithPlaceholder() || hasWarning == null
          ? _value.hasWarning
          // ignore: cast_nullable_to_non_nullable
          : hasWarning as bool,
    );
  }
}

extension $TaskRunDtoCopyWith on TaskRunDto {
  /// Returns a callable class used to build a new instance with modified fields.
  /// Example: `instanceOfTaskRunDto.copyWith(...)` or `instanceOfTaskRunDto.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$TaskRunDtoCWProxy get copyWith => _$TaskRunDtoCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

TaskRunDto _$TaskRunDtoFromJson(Map<String, dynamic> json) => TaskRunDto(
  id: const IntJsonConverter().fromJson(json['id']),
  taskKey: const StringJsonConverter().fromJson(json['task_key']),
  taskName: const StringJsonConverter().fromJson(json['task_name']),
  triggerType: const StringJsonConverter().fromJson(json['trigger_type']),
  state: const StringJsonConverter().fromJson(json['state']),
  progressCurrent: const NullableIntJsonConverter().fromJson(
    json['progress_current'],
  ),
  progressTotal: const NullableIntJsonConverter().fromJson(
    json['progress_total'],
  ),
  progressText: const NullableStringJsonConverter().fromJson(
    json['progress_text'],
  ),
  resultText: const NullableStringJsonConverter().fromJson(json['result_text']),
  resultSummary: asMapOrNull(json['result_summary']),
  errorMessage: const NullableStringJsonConverter().fromJson(
    json['error_message'],
  ),
  startedAt: const DateTimeJsonConverter().fromJson(json['started_at']),
  finishedAt: const DateTimeJsonConverter().fromJson(json['finished_at']),
  createdAt: const DateTimeJsonConverter().fromJson(json['created_at']),
  updatedAt: const DateTimeJsonConverter().fromJson(json['updated_at']),
  hasWarning: json['has_warning'] == null
      ? false
      : const BoolJsonConverter().fromJson(json['has_warning']),
);
