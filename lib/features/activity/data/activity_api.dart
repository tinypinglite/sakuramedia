import 'package:sakuramedia/core/json/json_parse.dart';
import 'package:sakuramedia/core/network/api_client.dart';
import 'package:sakuramedia/core/network/api_sse_event.dart';
import 'package:sakuramedia/core/network/paginated_response_dto.dart';
import 'package:sakuramedia/features/activity/data/activity_bootstrap_dto.dart';
import 'package:sakuramedia/features/activity/data/activity_event_stream_client.dart';
import 'package:sakuramedia/features/activity/data/job_metadata_dto.dart';
import 'package:sakuramedia/features/activity/data/activity_notification_dto.dart';
import 'package:sakuramedia/features/activity/data/activity_stream_event.dart';
import 'package:sakuramedia/features/activity/data/notification_read_result_dto.dart';
import 'package:sakuramedia/features/activity/data/resource_task_definition_dto.dart';
import 'package:sakuramedia/features/activity/data/resource_task_record_dto.dart';
import 'package:sakuramedia/features/activity/data/task_run_dto.dart';

class ActivityApi {
  const ActivityApi({
    required ApiClient apiClient,
    required ActivityEventStreamClient streamClient,
  }) : _apiClient = apiClient,
       _streamClient = streamClient;

  final ApiClient _apiClient;
  final ActivityEventStreamClient _streamClient;

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
  }) async {
    final response = await _apiClient.get(
      '/system/notifications',
      queryParameters: <String, dynamic>{
        'page': page,
        'page_size': pageSize,
        if (category != null && category.trim().isNotEmpty)
          'category': category,
      },
    );
    return PaginatedResponseDto<ActivityNotificationDto>.fromJson(
      response,
      ActivityNotificationDto.fromJson,
    );
  }

  /// 批量已读：把 [ids] 对应的通知置已读，返回最新 `unread_count` 供刷新角标。
  Future<NotificationReadResultDto> markNotificationsRead(
    List<int> ids,
  ) async {
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
  }) async {
    final response = await _apiClient.post('/system/jobs/$taskKey/run');
    return ManualJobTriggerResponseDto.fromJson(response);
  }

  Future<List<TaskRunDto>> getActiveTaskRuns() async {
    final response = await _apiClient.getList('/system/task-runs/active');
    return response.map(TaskRunDto.fromJson).toList(growable: false);
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

  Future<List<ResourceTaskDefinitionDto>> getResourceTaskDefinitions() async {
    final response = await _apiClient.getList(
      '/system/resource-task-states/definitions',
    );
    return response
        .map(ResourceTaskDefinitionDto.fromJson)
        .toList(growable: false);
  }

  Future<PaginatedResponseDto<ResourceTaskRecordDto>> getResourceTaskRecords({
    required String taskKey,
    int page = 1,
    int pageSize = 20,
    String? state,
    String? search,
    String? sort,
  }) async {
    final response = await _apiClient.get(
      '/system/resource-task-states',
      queryParameters: <String, dynamic>{
        'task_key': taskKey,
        'page': page,
        'page_size': pageSize,
        if (state != null && state.trim().isNotEmpty) 'state': state,
        if (search != null && search.trim().isNotEmpty) 'search': search,
        if (sort != null && sort.trim().isNotEmpty) 'sort': sort,
      },
    );
    return PaginatedResponseDto<ResourceTaskRecordDto>.fromJson(
      response,
      ResourceTaskRecordDto.fromJson,
    );
  }

  Stream<ActivityStreamEvent> streamEvents({required int afterEventId}) {
    return _streamClient
        .connect(afterEventId: afterEventId)
        .map(_mapStreamEvent);
  }

  ActivityStreamEvent _mapStreamEvent(ApiSseEvent event) {
    final payload = event.jsonData;
    return switch (event.event) {
      'notification_created' || 'notification_updated' => ActivityStreamEvent(
        id: event.id,
        event: event.event,
        notification: ActivityNotificationDto.fromJson(payload),
      ),
      'notifications_read' => ActivityStreamEvent(
        id: event.id,
        event: event.event,
        notificationIds: _parseIds(payload['ids']),
        unreadCount: asIntOrNull(payload['unread_count']),
      ),
      'notifications_read_all' => ActivityStreamEvent(
        id: event.id,
        event: event.event,
        unreadCount: asIntOrNull(payload['unread_count']),
      ),
      'task_run_created' || 'task_run_updated' => ActivityStreamEvent(
        id: event.id,
        event: event.event,
        taskRun: TaskRunDto.fromJson(payload),
      ),
      _ => ActivityStreamEvent(id: event.id, event: event.event),
    };
  }

  List<int> _parseIds(dynamic value) {
    if (value is! List) {
      return const <int>[];
    }
    final ids = <int>[];
    for (final item in value) {
      final parsed = asIntOrNull(item);
      if (parsed != null) {
        ids.add(parsed);
      }
    }
    return ids;
  }
}
