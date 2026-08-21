import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:sakuramedia/core/network/providers/api_client_provider.dart';
import 'package:sakuramedia/core/network/sse_event_stream_client.dart';

part 'sse_event_stream_client_provider.g.dart';

/// 全局 SSE 流客户端（原生装配）。dispose 与 provider 生命周期配对。
@Riverpod(keepAlive: true)
SseEventStreamClient sseEventStreamClient(Ref ref) {
  final client = createSseEventStreamClient(
    apiClient: ref.watch(apiClientProvider),
  );
  ref.onDispose(client.dispose);
  return client;
}
