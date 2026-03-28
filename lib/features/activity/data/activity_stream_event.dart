import 'package:sakuramedia/features/activity/data/activity_notification_dto.dart';
import 'package:sakuramedia/features/activity/data/task_run_dto.dart';

class ActivityStreamEvent {
  const ActivityStreamEvent({
    required this.id,
    required this.event,
    this.notification,
    this.taskRun,
  });

  final int? id;
  final String event;
  final ActivityNotificationDto? notification;
  final TaskRunDto? taskRun;

  bool get isHeartbeat => event == 'heartbeat';
  bool get isNotificationCreated =>
      event == 'notification_created' && notification != null;
  bool get isNotificationUpdated =>
      event == 'notification_updated' && notification != null;
  bool get isTaskRunCreated => event == 'task_run_created' && taskRun != null;
  bool get isTaskRunUpdated => event == 'task_run_updated' && taskRun != null;
}
