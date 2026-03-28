import 'package:flutter_test/flutter_test.dart';
import 'package:dio/dio.dart';
import 'package:sakuramedia/core/network/api_client.dart';
import 'package:sakuramedia/core/network/api_exception.dart';
import 'package:sakuramedia/core/session/session_store.dart';

import '../../support/fake_http_client_adapter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SessionStore sessionStore;
  late ApiClient apiClient;
  late FakeHttpClientAdapter adapter;

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
  });

  tearDown(() {
    apiClient.dispose();
  });

  test('postSse decodes multi-line SSE events', () async {
    adapter.enqueueSse(
      method: 'POST',
      path: '/movies/search/javdb/stream',
      chunks: <String>[
        'id: 7\n'
            'event: search_started\n'
            'data: {"movie_number":"ABP-123"}\n\n',
        'event: completed\n'
            'data: {"success":true,\n'
            'data: "movies":[]}\n\n',
      ],
    );

    final events =
        await apiClient
            .postSse(
              '/movies/search/javdb/stream',
              data: <String, dynamic>{'movie_number': 'ABP-123'},
            )
            .toList();

    expect(events[0].id, 7);
    expect(events[0].event, 'search_started');
    expect(events[0].jsonData['movie_number'], 'ABP-123');
    expect(events[1].event, 'completed');
    expect(events[1].jsonData['success'], isTrue);
    expect(events[1].jsonData['movies'], isEmpty);
  });

  test('getSse sends GET request with event stream accept header', () async {
    adapter.enqueueSse(
      method: 'GET',
      path: '/system/events/stream',
      chunks: <String>[
        'id: 12\n'
            'event: heartbeat\n'
            'data: {}\n\n',
      ],
    );

    final events =
        await apiClient
            .getSse(
              '/system/events/stream',
              queryParameters: <String, dynamic>{'after_event_id': 11},
            )
            .toList();

    expect(events.single.id, 12);
    expect(events.single.event, 'heartbeat');
    expect(
      adapter.requests.single.headers[Headers.acceptHeader],
      'text/event-stream',
    );
    expect(
      adapter.requests.single.uri.queryParameters['after_event_id'],
      '11',
    );
  });

  test('postSse uses a one-minute receive timeout override', () async {
    adapter.enqueueSse(
      method: 'POST',
      path: '/movies/search/javdb/stream',
      chunks: <String>[
        'event: completed\n'
            'data: {"success":true,"movies":[]}\n\n',
      ],
    );

    await apiClient.postSse('/movies/search/javdb/stream').toList();

    expect(adapter.requests.single.receiveTimeout, const Duration(minutes: 1));
  });

  test('postSse maps non-200 responses to ApiException', () async {
    adapter.enqueueSse(
      method: 'POST',
      path: '/movies/search/javdb/stream',
      statusCode: 500,
      chunks: <String>['{"error":{"code":"server_error","message":"boom"}}'],
      headers: const <String, List<String>>{
        'content-type': <String>['application/json'],
      },
    );

    expect(
      () => apiClient.postSse('/movies/search/javdb/stream').toList(),
      throwsA(isA<ApiException>()),
    );
  });
}
