import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
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
    apiClient = ApiClient(sessionStore: sessionStore);
    adapter = FakeHttpClientAdapter();
    apiClient.rawDio.httpClientAdapter = adapter;
    apiClient.rawRefreshDio.httpClientAdapter = adapter;
  });

  tearDown(() {
    apiClient.dispose();
  });

  test('maps connection failures to transport metadata with base url', () async {
    final failures = <ApiException>[];
    final subscription = apiClient.connectionFailures.listen(failures.add);
    addTearDown(subscription.cancel);

    adapter.enqueueResponder(
      method: 'GET',
      path: '/status',
      responder: (options, _) async {
        throw DioException(
          requestOptions: options,
          type: DioExceptionType.connectionError,
          message:
              'The connection errored: The XMLHttpRequest onError callback was called.',
        );
      },
    );

    await expectLater(
      () => apiClient.get('/status'),
      throwsA(
        isA<ApiException>()
            .having(
              (ApiException error) => error.transportFailureKind,
              'transportFailureKind',
              ApiTransportFailureKind.connection,
            )
            .having(
              (ApiException error) => error.baseUrl,
              'baseUrl',
              'https://api.example.com',
            ),
      ),
    );
    expect(failures, hasLength(1));
    expect(failures.single.baseUrl, 'https://api.example.com');
  });

  test('maps timeout failures to transport metadata with base url', () async {
    final failures = <ApiException>[];
    final subscription = apiClient.connectionFailures.listen(failures.add);
    addTearDown(subscription.cancel);

    adapter.enqueueResponder(
      method: 'GET',
      path: '/status',
      responder: (options, _) async {
        throw DioException(
          requestOptions: options,
          type: DioExceptionType.receiveTimeout,
          message: 'Request timed out',
        );
      },
    );

    await expectLater(
      () => apiClient.get('/status'),
      throwsA(
        isA<ApiException>()
            .having(
              (ApiException error) => error.transportFailureKind,
              'transportFailureKind',
              ApiTransportFailureKind.timeout,
            )
            .having(
              (ApiException error) => error.baseUrl,
              'baseUrl',
              'https://api.example.com',
            ),
      ),
    );
    expect(failures, isEmpty);
  });

  test('reports the request target for absolute url failures', () async {
    const url =
        'https://raw.githubusercontent.com/example/market/main/index.json';
    adapter.enqueueResponder(
      method: 'GET',
      path: url,
      responder: (options, _) async {
        throw DioException(
          requestOptions: options,
          type: DioExceptionType.connectionError,
          message: 'Connection failed',
        );
      },
    );

    await expectLater(
      () => apiClient.get(url, requiresAuth: false),
      throwsA(
        isA<ApiException>()
            .having(
              (ApiException error) => error.transportFailureKind,
              'transportFailureKind',
              ApiTransportFailureKind.connection,
            )
            .having(
              (ApiException error) => error.baseUrl,
              'baseUrl',
              'https://raw.githubusercontent.com',
            ),
      ),
    );
  });

  test('does not map non-network unknown failures to connection', () async {
    adapter.enqueueResponder(
      method: 'GET',
      path: '/status',
      responder: (options, _) async {
        throw DioException(
          requestOptions: options,
          type: DioExceptionType.unknown,
          error: TypeError(),
          message:
              "type 'String' is not a subtype of type "
              "'Map<String, dynamic>?' in type cast",
        );
      },
    );

    await expectLater(
      () => apiClient.get('/status'),
      throwsA(
        isA<ApiException>()
            .having(
              (ApiException error) => error.transportFailureKind,
              'transportFailureKind',
              isNull,
            )
            .having(
              (ApiException error) => error.message,
              'message',
              contains('not a subtype'),
            ),
      ),
    );
  });

  test(
    'health checks are unauthenticated and never report connection failures',
    () async {
      final failures = <ApiException>[];
      final subscription = apiClient.connectionFailures.listen(failures.add);
      addTearDown(subscription.cancel);

      await sessionStore.saveTokens(
        accessToken: 'access-token',
        refreshToken: 'refresh-token',
        expiresAt: DateTime.parse('2030-01-01T00:00:00Z'),
      );

      adapter.enqueueJson(
        method: 'GET',
        path: '/healthz',
        body: <String, dynamic>{'status': 'ok', 'boot_id': 'boot-1'},
      );
      final health = await apiClient.fetchHealth();
      expect(health.healthy, isTrue);
      expect(health.bootId, 'boot-1');
      final successRequest = adapter.requests.last;
      expect(successRequest.headers['Authorization'], isNull);
      expect(successRequest.connectTimeout, const Duration(seconds: 5));
      expect(successRequest.receiveTimeout, const Duration(seconds: 5));

      adapter.enqueueResponder(
        method: 'GET',
        path: '/healthz',
        responder: (options, _) async {
          throw DioException(
            requestOptions: options,
            type: DioExceptionType.connectionError,
          );
        },
      );
      final down = await apiClient.fetchHealth();
      expect(down.healthy, isFalse);
      expect(down.bootId, isNull);
      expect(failures, isEmpty);
    },
  );
}
