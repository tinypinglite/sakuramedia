import 'package:sakuramedia/core/network/api_client.dart';
import 'package:sakuramedia/core/network/api_sse_event.dart';
import 'package:sakuramedia/core/session/session_store.dart';
import 'package:sakuramedia/features/activity/data/activity_event_stream_client.dart';

ActivityEventStreamClient createPlatformActivityEventStreamClient({
  required ApiClient apiClient,
  required SessionStore sessionStore,
}) {
  return _IoActivityEventStreamClient(apiClient);
}

class _IoActivityEventStreamClient implements ActivityEventStreamClient {
  _IoActivityEventStreamClient(this._apiClient);

  final ApiClient _apiClient;

  @override
  Stream<ApiSseEvent> connect({required int afterEventId}) {
    return _apiClient.getSse(
      '/system/events/stream',
      queryParameters: <String, dynamic>{'after_event_id': afterEventId},
    );
  }

  @override
  void dispose() {}
}
