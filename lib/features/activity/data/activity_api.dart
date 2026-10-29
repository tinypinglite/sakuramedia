import 'package:sakuramedia/core/network/api_client.dart';
import 'package:sakuramedia/core/network/paginated_response_dto.dart';
import 'package:sakuramedia/features/activity/data/activity_bootstrap_dto.dart';
import 'package:sakuramedia/features/activity/data/job_metadata_dto.dart';
import 'package:sakuramedia/features/activity/data/activity_notification_dto.dart';
import 'package:sakuramedia/features/activity/data/notification_read_result_dto.dart';
import 'package:sakuramedia/features/activity/data/task_attention_dto.dart';
import 'package:sakuramedia/features/activity/data/task_run_dto.dart';

/// 任务运行记录的范围值：默认只看「操作」类记录（排除定时触发的例行成功），
/// 显式按任务 key / 触发来源筛选时看全量。
abstract final class ActivityTaskRunScope {
  static const String all = 'all';
  static const String operations = 'operations';
}

class ActivityApi {
  const ActivityApi({required ApiClient apiClient}) : _apiClient = apiClient;

  final ApiClient _apiClient;

  Future<ActivityBootstrapDto> getBootstrap({
    String? notificationCategory,
    String? taskState,
    String? taskKey,
    String? taskTriggerType,
    String? taskSort,
    String? taskScope,
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
        if (taskScope != null && taskScope.trim().isNotEmpty)
          'task_scope': taskScope,
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
    final response = await _apiClient.patch(
      '/system/notifications',
      data: <String, dynamic>{'ids': ids, 'is_read': true},
    );
    return NotificationReadResultDto.fromJson(response);
  }

  /// 一键全部已读，返回最新 `unread_count`（通常为 0）。
  Future<NotificationReadResultDto> markAllNotificationsRead() async {
    final response = await _apiClient.patch(
      '/system/notifications',
      data: <String, dynamic>{'all': true, 'is_read': true},
    );
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
      '/system/jobs/$taskKey/runs',
      data: params,
    );
    return ManualJobTriggerResponseDto.fromJson(response);
  }

  Future<List<TaskRunDto>> getActiveTaskRuns() async {
    final response = await _apiClient.getList('/system/task-runs/active');
    return response.map(TaskRunDto.fromJson).toList(growable: false);
  }

  /// 需要关注的任务（最新运行失败或带警告），按最近出问题时间倒序。
  Future<List<TaskAttentionDto>> getTaskAttention({int limit = 50}) async {
    final response = await _apiClient.getList(
      '/system/task-runs/attention',
      queryParameters: <String, dynamic>{'limit': limit},
    );
    return response.map(TaskAttentionDto.fromJson).toList(growable: false);
  }

  Future<PaginatedResponseDto<TaskRunDto>> getTaskRuns({
    int page = 1,
    int pageSize = 20,
    String? state,
    String? taskKey,
    String? triggerType,
    String? sort,
    String? scope,
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
        if (scope != null && scope.trim().isNotEmpty) 'scope': scope,
      },
    );
    return PaginatedResponseDto<TaskRunDto>.fromJson(
      response,
      TaskRunDto.fromJson,
    );
  }
}
