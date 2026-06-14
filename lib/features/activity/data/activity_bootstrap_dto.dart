import 'package:sakuramedia/core/json/json_parse.dart';
import 'package:sakuramedia/core/network/paginated_response_dto.dart';
import 'package:sakuramedia/features/activity/data/activity_notification_dto.dart';
import 'package:sakuramedia/features/activity/data/task_run_dto.dart';

class ActivityBootstrapDto {
  const ActivityBootstrapDto({
    required this.latestEventId,
    required this.notifications,
    required this.unreadCount,
    required this.activeTaskRuns,
    required this.taskRuns,
  });

  final int latestEventId;
  final PaginatedResponseDto<ActivityNotificationDto> notifications;
  final int unreadCount;
  final List<TaskRunDto> activeTaskRuns;
  final PaginatedResponseDto<TaskRunDto> taskRuns;

  factory ActivityBootstrapDto.fromJson(Map<String, dynamic> json) {
    final activeTaskRunsJson = json['active_task_runs'];
    final activeTaskRuns =
        activeTaskRunsJson is List
            ? activeTaskRunsJson
                .whereType<Map>()
                .map(
                  (item) => TaskRunDto.fromJson(
                    item.map(
                      (dynamic key, dynamic value) =>
                          MapEntry(key.toString(), value),
                    ),
                  ),
                )
                .toList(growable: false)
            : const <TaskRunDto>[];

    return ActivityBootstrapDto(
      latestEventId: asInt(json['latest_event_id']),
      notifications: PaginatedResponseDto<ActivityNotificationDto>.fromJson(
        asMap(json['notifications']),
        ActivityNotificationDto.fromJson,
      ),
      unreadCount: asInt(json['unread_count']),
      activeTaskRuns: activeTaskRuns,
      taskRuns: PaginatedResponseDto<TaskRunDto>.fromJson(
        asMap(json['task_runs']),
        TaskRunDto.fromJson,
      ),
    );
  }
}
