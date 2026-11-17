import 'package:json_annotation/json_annotation.dart';
import 'package:sakuramedia/core/json/dto_json_codec.dart';
import 'package:sakuramedia/core/json/json_parse.dart';
import 'package:sakuramedia/core/network/paginated_response_dto.dart';
import 'package:sakuramedia/features/activity/data/activity_notification_dto.dart';
import 'package:sakuramedia/features/activity/data/task_run_dto.dart';

part 'activity_bootstrap_dto.g.dart';

@JsonSerializable(converters: dtoJsonConverters, createToJson: false)
class ActivityBootstrapDto {
  const ActivityBootstrapDto({
    required this.notifications,
    required this.unreadCount,
    required this.activeTaskRuns,
    required this.taskRuns,
  });

  @JsonKey(fromJson: _notificationsFromJson)
  final PaginatedResponseDto<ActivityNotificationDto> notifications;

  final int unreadCount;

  @JsonKey(fromJson: _activeTaskRunsFromJson)
  final List<TaskRunDto> activeTaskRuns;

  @JsonKey(fromJson: _taskRunsFromJson)
  final PaginatedResponseDto<TaskRunDto> taskRuns;

  factory ActivityBootstrapDto.fromJson(Map<String, dynamic> json) =>
      _$ActivityBootstrapDtoFromJson(json);
}

PaginatedResponseDto<ActivityNotificationDto> _notificationsFromJson(
  Object? value,
) => PaginatedResponseDto<ActivityNotificationDto>.fromJson(
  asMap(value),
  ActivityNotificationDto.fromJson,
);

PaginatedResponseDto<TaskRunDto> _taskRunsFromJson(Object? value) =>
    PaginatedResponseDto<TaskRunDto>.fromJson(
      asMap(value),
      TaskRunDto.fromJson,
    );

List<TaskRunDto> _activeTaskRunsFromJson(Object? value) =>
    asObjectList(value, TaskRunDto.fromJson);
