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
  });

  test('maps timeout failures to transport metadata with base url', () async {
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
  });
}
