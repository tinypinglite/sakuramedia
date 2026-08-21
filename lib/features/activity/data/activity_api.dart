import 'package:sakuramedia/core/network/api_client.dart';
import 'package:sakuramedia/core/network/paginated_response_dto.dart';
import 'package:sakuramedia/features/activity/data/activity_bootstrap_dto.dart';
import 'package:sakuramedia/features/activity/data/job_metadata_dto.dart';
import 'package:sakuramedia/features/activity/data/activity_notification_dto.dart';
import 'package:sakuramedia/features/activity/data/notification_read_result_dto.dart';
import 'package:sakuramedia/features/activity/data/task_run_dto.dart';

class ActivityApi {
  const ActivityApi({required ApiClient apiClient}) : _apiClient = apiClient;

  final ApiClient _apiClient;

  Future<ActivityBootstrapDto> getBootstrap({
    String? notificationCategory,
    String? taskState,
    String? taskKey,
    String? taskTriggerType,
    String? taskSort,
  }) async {
    final response = await _apiClient.get(
      '/system/activity/bootstrap',
      queryParameters: <String, dynamic>{
        if (notificationCategory != null &&
            notificationCategory.trim().isNotEmpty)
          'notification_category': notificationCategory,
        if (taskState != null && taskState.trim().isNotEmpty)
          'task_state': taskState,
        if (taskKey != null && taskKey.trim().isNotEmpty) 'task_key': taskKey,
        if (taskTriggerType != null && taskTriggerType.trim().isNotEmpty)
          'task_trigger_type': taskTriggerType,
        if (taskSort != null && taskSort.trim().isNotEmpty)
          'task_sort': taskSort,
      },
    );
    return ActivityBootstrapDto.fromJson(response);
  }

  Future<PaginatedResponseDto<ActivityNotificationDto>> getNotifications({
    int page = 1,
    int pageSize = 20,
    String? category,
    bool? isRead,
  }) async {
    final response = await _apiClient.get(
      '/system/notifications',
      queryParameters: <String, dynamic>{
        'page': page,
        'page_size': pageSize,
        if (category != null && category.trim().isNotEmpty)
          'category': category,
        if (isRead != null) 'is_read': isRead,
      },
    );
    return PaginatedResponseDto<ActivityNotificationDto>.fromJson(
      response,
      ActivityNotificationDto.fromJson,
    );
  }

  /// 批量已读：把 [ids] 对应的通知置已读，返回最新 `unread_count` 供刷新角标。
  Future<NotificationReadResultDto> markNotificationsRead(List<int> ids) async {
    final response = await _apiClient.post(
      '/system/notifications/read',
      data: <String, dynamic>{'ids': ids},
    );
    return NotificationReadResultDto.fromJson(response);
  }

  /// 一键全部已读，返回最新 `unread_count`（通常为 0）。
  Future<NotificationReadResultDto> markAllNotificationsRead() async {
    final response = await _apiClient.post('/system/notifications/read-all');
    return NotificationReadResultDto.fromJson(response);
  }

  Future<List<JobMetadataDto>> getJobs() async {
    final response = await _apiClient.getList('/system/jobs');
    return response.map(JobMetadataDto.fromJson).toList(growable: false);
  }

  Future<ManualJobTriggerResponseDto> triggerJob({
    required String taskKey,
    Map<String, dynamic>? params,
  }) async {
    final response = await _apiClient.post(
      '/system/jobs/$taskKey/run',
      data: params,
    );
    return ManualJobTriggerResponseDto.fromJson(response);
  }

  Future<PaginatedResponseDto<TaskRunDto>> getTaskRuns({
    int page = 1,
    int pageSize = 20,
    String? state,
    String? taskKey,
    String? triggerType,
    String? sort,
  }) async {
    final response = await _apiClient.get(
      '/system/task-runs',
      queryParameters: <String, dynamic>{
        'page': page,
        'page_size': pageSize,
        if (state != null && state.trim().isNotEmpty) 'state': state,
        if (taskKey != null && taskKey.trim().isNotEmpty) 'task_key': taskKey,
        if (triggerType != null && triggerType.trim().isNotEmpty)
          'trigger_type': triggerType,
        if (sort != null && sort.trim().isNotEmpty) 'sort': sort,
      },
    );
    return PaginatedResponseDto<TaskRunDto>.fromJson(
      response,
      TaskRunDto.fromJson,
    );
  }
}
