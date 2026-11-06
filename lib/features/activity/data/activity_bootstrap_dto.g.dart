// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'activity_bootstrap_dto.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ActivityBootstrapDto _$ActivityBootstrapDtoFromJson(
  Map<String, dynamic> json,
) => ActivityBootstrapDto(
  notifications: _notificationsFromJson(json['notifications']),
  unreadCount: const IntJsonConverter().fromJson(json['unread_count']),
  activeTaskRuns: _activeTaskRunsFromJson(json['active_task_runs']),
  taskRuns: _taskRunsFromJson(json['task_runs']),
);
