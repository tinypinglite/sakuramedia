import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:sakuramedia/core/network/api_client.dart';
import 'package:sakuramedia/core/session/session_store.dart';

import '../../support/fake_http_client_adapter.dart';

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

  test('getBytes downloads relative path payload', () async {
    adapter.enqueueBytes(
      method: 'GET',
      path: '/files/images/query.webp?expires=1&signature=abc',
      body: Uint8List.fromList(const <int>[1, 2, 3]),
    );

    final bytes = await apiClient.getBytes(
      '/files/images/query.webp?expires=1&signature=abc',
    );

    expect(bytes, Uint8List.fromList(const <int>[1, 2, 3]));
    expect(
      adapter.requests.single.headers['Authorization'],
      'Bearer access-token',
    );
  });

  test('getBytes downloads absolute url payload', () async {
    adapter.enqueueBytes(
      method: 'GET',
      path: 'https://cdn.example.com/file.webp',
      body: Uint8List.fromList(const <int>[4, 5, 6]),
    );

    final bytes = await apiClient.getBytes('https://cdn.example.com/file.webp');

    expect(bytes, Uint8List.fromList(const <int>[4, 5, 6]));
    expect(adapter.requests.single.path, 'https://cdn.example.com/file.webp');
  });
}
