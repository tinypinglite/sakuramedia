import 'package:sakuramedia/core/network/api_client.dart';
import 'package:sakuramedia/core/network/api_sse_event.dart';
import 'package:sakuramedia/core/network/paginated_response_dto.dart';
import 'package:sakuramedia/features/activity/data/activity_bootstrap_dto.dart';
import 'package:sakuramedia/features/activity/data/activity_event_stream_client.dart';
import 'package:sakuramedia/features/activity/data/activity_notification_dto.dart';
import 'package:sakuramedia/features/activity/data/activity_stream_event.dart';
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
    bool? notificationArchived,
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
        if (notificationArchived != null)
          'notification_archived': notificationArchived,
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
    bool? archived,
  }) async {
    final response = await _apiClient.get(
      '/system/notifications',
      queryParameters: <String, dynamic>{
        'page': page,
        'page_size': pageSize,
        if (category != null && category.trim().isNotEmpty)
          'category': category,
        if (archived != null) 'archived': archived,
      },
    );
    return PaginatedResponseDto<ActivityNotificationDto>.fromJson(
      response,
      ActivityNotificationDto.fromJson,
    );
  }

  Future<void> markNotificationRead({required int notificationId}) async {
    await _apiClient.patch('/system/notifications/$notificationId/read');
  }

  Future<int> getUnreadCount() async {
    final response = await _apiClient.get('/system/notifications/unread-count');
    final value = response['unread_count'];
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
      'task_run_created' || 'task_run_updated' => ActivityStreamEvent(
        id: event.id,
        event: event.event,
        taskRun: TaskRunDto.fromJson(payload),
      ),
      _ => ActivityStreamEvent(id: event.id, event: event.event),
    };
  }
}
