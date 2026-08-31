import 'package:flutter_test/flutter_test.dart';
import 'package:sakuramedia/core/network/api_client.dart';
import 'package:sakuramedia/core/session/session_store.dart';
import 'package:sakuramedia/features/media_import/data/subtitle_import_api.dart';

import '../../../support/fake_http_client_adapter.dart';

void main() {
  late SessionStore sessionStore;
  late ApiClient apiClient;
  late FakeHttpClientAdapter adapter;
  late SubtitleImportApi api;

  setUp(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    sessionStore = SessionStore.inMemory();
    await sessionStore.saveBaseUrl('https://api.example.com');
    await sessionStore.saveTokens(
      accessToken: 'access-token',
      refreshToken: 'refresh-token',
      expiresAt: DateTime.parse('2026-12-31T12:00:00Z'),
    );
    apiClient = ApiClient(sessionStore: sessionStore);
    adapter = FakeHttpClientAdapter();
    apiClient.rawDio.httpClientAdapter = adapter;
    apiClient.rawRefreshDio.httpClientAdapter = adapter;
    api = SubtitleImportApi(apiClient: apiClient);
  });

  tearDown(() {
    apiClient.dispose();
    sessionStore.dispose();
  });

  test('createSubtitleImport posts the accepted task-run contract', () async {
    adapter.enqueueJson(
      method: 'POST',
      path: '/subtitle-imports',
      statusCode: 202,
      body: <String, dynamic>{
        'task_run_id': 42,
        'task_key': 'subtitle_import',
        'state': 'accepted',
      },
    );

    final response = await api.createSubtitleImport(
      sourcePath: ' /mnt/incoming/subtitles ',
    );

    expect(response.taskRunId, 42);
    expect(response.taskKey, 'subtitle_import');
    expect(response.state, 'accepted');
    expect(adapter.requests.single.body, <String, dynamic>{
      'source_path': '/mnt/incoming/subtitles',
    });
  });
}
