import 'package:sakuramedia/core/network/api_client.dart';
import 'package:sakuramedia/core/network/api_sse_event.dart';

abstract class SseEventStreamClient {
  Stream<ApiSseEvent> connect(
    String path, {
    Map<String, dynamic>? queryParameters,
  });

  void dispose();
}

SseEventStreamClient createSseEventStreamClient({
  required ApiClient apiClient,
}) {
  return _ApiClientSseEventStreamClient(apiClient);
}

class _ApiClientSseEventStreamClient implements SseEventStreamClient {
  _ApiClientSseEventStreamClient(this._apiClient);

  final ApiClient _apiClient;

  @override
  Stream<ApiSseEvent> connect(
    String path, {
    Map<String, dynamic>? queryParameters,
  }) {
    return _apiClient.getSse(path, queryParameters: queryParameters);
  }

  @override
  void dispose() {}
}
