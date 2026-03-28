import 'package:sakuramedia/core/network/api_client.dart';
import 'package:sakuramedia/core/network/api_sse_event.dart';
import 'package:sakuramedia/core/network/paginated_response_dto.dart';
import 'package:sakuramedia/features/activity/data/activity_event_stream_client.dart';
import 'package:sakuramedia/features/activity/data/activity_notification_dto.dart';
import 'package:sakuramedia/features/activity/data/activity_stream_event.dart';
import 'package:sakuramedia/features/activity/data/task_run_dto.dart';

class ActivityApi {
  const ActivityApi({
    required ApiClient apiClient,
    required ActivityEventStreamClient streamClient,
  }) : _apiClient = apiClient,
       _streamClient = streamClient;

  final ApiClient _apiClient;
  final ActivityEventStreamClient _streamClient;

  Future<PaginatedResponseDto<ActivityNotificationDto>> getNotifications({
    int page = 1,
    int pageSize = 20,
    String? category,
    String? level,
    bool? archived,
  }) async {
    final response = await _apiClient.get(
      '/system/notifications',
      queryParameters: <String, dynamic>{
        'page': page,
        'page_size': pageSize,
        if (category != null && category.trim().isNotEmpty)
          'category': category,
        if (level != null && level.trim().isNotEmpty) 'level': level,
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

  Future<void> archiveNotification({required int notificationId}) async {
    await _apiClient.patch('/system/notifications/$notificationId/archive');
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
