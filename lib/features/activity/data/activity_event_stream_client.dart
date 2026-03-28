import 'package:sakuramedia/core/network/api_client.dart';
import 'package:sakuramedia/core/network/api_sse_event.dart';
import 'package:sakuramedia/core/session/session_store.dart';
import 'package:sakuramedia/features/activity/data/activity_event_stream_client_stub.dart'
    if (dart.library.js_interop) 'package:sakuramedia/features/activity/data/activity_event_stream_client_web.dart';

class ActivityEventStreamUnsupportedException implements Exception {
  const ActivityEventStreamUnsupportedException([this.message]);

  final String? message;

  @override
  String toString() {
    if (message == null || message!.trim().isEmpty) {
      return 'ActivityEventStreamUnsupportedException';
    }
    return 'ActivityEventStreamUnsupportedException: $message';
  }
}

abstract class ActivityEventStreamClient {
  Stream<ApiSseEvent> connect({required int afterEventId});

  void dispose();
}

ActivityEventStreamClient createActivityEventStreamClient({
  required ApiClient apiClient,
  required SessionStore sessionStore,
}) {
  return createPlatformActivityEventStreamClient(
    apiClient: apiClient,
    sessionStore: sessionStore,
  );
}
