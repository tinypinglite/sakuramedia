import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sakuramedia/core/network/api_client.dart';
import 'package:sakuramedia/core/network/api_exception.dart';
import 'package:sakuramedia/core/network/sse_event_stream_client.dart';
import 'package:sakuramedia/core/session/session_store.dart';

import '../../support/fake_http_client_adapter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SessionStore sessionStore;
  late ApiClient apiClient;
  late FakeHttpClientAdapter adapter;
  late SseEventStreamClient streamClient;

  setUp(() async {
    sessionStore = SessionStore.inMemory();
    await sessionStore.saveBaseUrl('https://api.example.com');
    await sessionStore.saveTokens(
      accessToken: 'access-token',
      refreshToken: 'refresh-token',
      expiresAt: DateTime.parse('2026-03-08T10:00:00Z'),
    );
    apiClient = ApiClient(sessionStore: sessionStore);
    adapter = FakeHttpClientAdapter();
    apiClient.rawDio.httpClientAdapter = adapter;
    apiClient.rawRefreshDio.httpClientAdapter = adapter;
    streamClient = createSseEventStreamClient(
      apiClient: apiClient,
      sessionStore: sessionStore,
    );
  });

  tearDown(() {
    streamClient.dispose();
    apiClient.dispose();
  });

  test('connect forwards arbitrary path and query parameters as GET', () async {
    adapter.enqueueSse(
      method: 'GET',
      path: '/test/stream',
      chunks: <String>[
        'event: heartbeat\n'
            'data: {}\n\n',
      ],
    );

    final events =
        await streamClient
            .connect(
              '/test/stream',
              queryParameters: <String, dynamic>{'client_id': 7},
            )
            .toList();

    expect(events.single.event, 'heartbeat');
    final recorded = adapter.requests.single;
    expect(recorded.method, 'GET');
    expect(recorded.path, '/test/stream');
    expect(recorded.uri.queryParameters['client_id'], '7');
    expect(recorded.headers[Headers.acceptHeader], 'text/event-stream');
  });

  test(
    'connect decodes multi-event frames with and without id lines',
    () async {
      adapter.enqueueSse(
        method: 'GET',
        path: '/test/stream',
        chunks: <String>[
          'event: snapshot\n'
              'data: {"client_id":1,"items":[]}\n\n',
          'event: download_task_updated\n'
              'data: {"task_id":42,"progress":0.5}\n\n',
        ],
      );

      final events =
      await streamClient.connect('/test/stream').toList();

      expect(events, hasLength(2));
      expect(events[0].id, isNull);
      expect(events[0].event, 'snapshot');
      expect(events[0].jsonData['client_id'], 1);
      expect(events[1].id, isNull);
      expect(events[1].event, 'download_task_updated');
      expect(events[1].jsonData['task_id'], 42);
    },
  );

  test('connect surfaces ApiException for non-2xx responses', () async {
    adapter.enqueueSse(
      method: 'GET',
        path: '/test/stream',
      statusCode: 500,
      chunks: <String>['{"error":{"code":"server_error","message":"boom"}}'],
      headers: const <String, List<String>>{
        'content-type': <String>['application/json'],
      },
    );

    expect(
      () => streamClient.connect('/test/stream').toList(),
      throwsA(isA<ApiException>()),
    );
  });
}
