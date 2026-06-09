import 'package:sakuramedia/features/activity/data/activity_notification_dto.dart';
import 'package:sakuramedia/features/activity/data/task_run_dto.dart';

class ActivityStreamEvent {
  const ActivityStreamEvent({
    required this.id,
    required this.event,
    this.notification,
    this.taskRun,
    this.notificationIds,
    this.unreadCount,
  });

  final int? id;
  final String event;
  final ActivityNotificationDto? notification;
  final TaskRunDto? taskRun;

  /// `notifications_read` 聚合事件携带的被置已读通知 id 列表。
  final List<int>? notificationIds;

  /// `notifications_read` / `notifications_read_all` 聚合事件携带的最新未读数。
  final int? unreadCount;

  bool get isHeartbeat => event == 'heartbeat';
  bool get isNotificationCreated =>
      event == 'notification_created' && notification != null;
  bool get isNotificationUpdated =>
      event == 'notification_updated' && notification != null;
  bool get isNotificationsRead => event == 'notifications_read';
  bool get isNotificationsReadAll => event == 'notifications_read_all';
  bool get isTaskRunCreated => event == 'task_run_created' && taskRun != null;
  bool get isTaskRunUpdated => event == 'task_run_updated' && taskRun != null;
}
