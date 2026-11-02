import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:sakuramedia/core/network/api_client.dart';
import 'package:sakuramedia/core/session/session_store.dart';
import 'package:sakuramedia/features/configuration/data/api/system_logs_api.dart';

import '../../../../support/fake_http_client_adapter.dart';

void main() {
  late SessionStore sessionStore;
  late ApiClient apiClient;
  late FakeHttpClientAdapter adapter;

  setUp(() async {
    sessionStore = SessionStore.inMemory();
    await sessionStore.saveBaseUrl('https://api.example.com');
    await sessionStore.saveTokens(
      accessToken: 'access-token',
      refreshToken: 'refresh-token',
      expiresAt: DateTime.parse('2026-03-10T12:00:00Z'),
    );
    apiClient = ApiClient(sessionStore: sessionStore);
    adapter = FakeHttpClientAdapter();
    apiClient.rawDio.httpClientAdapter = adapter;
    apiClient.rawRefreshDio.httpClientAdapter = adapter;
  });

  tearDown(() {
    apiClient.dispose();
  });

  test('downloads the selected archive range with redaction setting', () async {
    adapter.enqueueBytes(
      method: 'GET',
      path: '/system/logs/archive',
      body: Uint8List.fromList(const <int>[80, 75, 3, 4]),
    );
    final api = SystemLogsApi(apiClient: apiClient);

    final bytes = await api.downloadArchive(
      range: SystemLogRange.last7Days,
      redactSensitive: false,
    );

    expect(bytes, Uint8List.fromList(const <int>[80, 75, 3, 4]));
    final request = adapter.requests.single;
    expect(request.uri.queryParameters, <String, String>{
      'range': '7d',
      'redact_sensitive': 'false',
    });
    expect(request.receiveTimeout, const Duration(minutes: 2));
  });
}
