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
      latestEventId: _toInt(json['latest_event_id']),
      notifications: PaginatedResponseDto<ActivityNotificationDto>.fromJson(
        _toMap(json['notifications']),
        ActivityNotificationDto.fromJson,
      ),
      unreadCount: _toInt(json['unread_count']),
      activeTaskRuns: activeTaskRuns,
      taskRuns: PaginatedResponseDto<TaskRunDto>.fromJson(
        _toMap(json['task_runs']),
        TaskRunDto.fromJson,
      ),
    );
  }

  static Map<String, dynamic> _toMap(dynamic value) {
    if (value is Map<String, dynamic>) {
      return value;
    }
    if (value is Map) {
      return value.map(
        (dynamic key, dynamic data) => MapEntry(key.toString(), data),
      );
    }
    return const <String, dynamic>{};
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
