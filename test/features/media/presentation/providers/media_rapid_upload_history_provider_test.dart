import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sakuramedia/core/network/api_client.dart';
import 'package:sakuramedia/core/session/session_store.dart';
import 'package:sakuramedia/features/media/data/media_api.dart';
import 'package:sakuramedia/features/media/data/media_rapid_upload_dto.dart';
import 'package:sakuramedia/features/media/presentation/providers/media_api_provider.dart';
import 'package:sakuramedia/features/media/presentation/providers/media_rapid_upload_history_provider.dart';

import '../../../../support/fake_http_client_adapter.dart';

void main() {
  late SessionStore sessionStore;
  late ApiClient apiClient;
  late FakeHttpClientAdapter adapter;
  late MediaApi mediaApi;
  late ProviderContainer container;

  setUp(() async {
    sessionStore = SessionStore.inMemory();
    await sessionStore.saveBaseUrl('https://api.example.com');
    await sessionStore.saveTokens(
      accessToken: 'access-token',
      refreshToken: 'refresh-token',
      expiresAt: DateTime.parse('2026-05-13T12:00:00Z'),
    );
    apiClient = ApiClient(sessionStore: sessionStore);
    adapter = FakeHttpClientAdapter();
    apiClient.rawDio.httpClientAdapter = adapter;
    apiClient.rawRefreshDio.httpClientAdapter = adapter;
    mediaApi = MediaApi(apiClient: apiClient);
    container = ProviderContainer(
      overrides: [mediaApiProvider.overrideWithValue(mediaApi)],
      retry: (_, __) => null,
    );
  });

  tearDown(() {
    container.dispose();
    apiClient.dispose();
    sessionStore.dispose();
  });

  test('build loads first page of batches', () async {
    adapter.enqueueJson(
      method: 'GET',
      path: '/media/rapid-uploads',
      body: <String, dynamic>{
        'items': [_batchJson(id: 1, state: 'completed', total: 3, ok: 3)],
        'page': 1,
        'page_size': 20,
        'total': 1,
      },
    );

    final state = await container.read(mediaRapidUploadHistoryProvider.future);

    expect(state.items, hasLength(1));
    expect(state.items.single.state, MediaRapidUploadBatchState.completed);
  });

  test('refreshBatch upserts new batch at head when missing', () async {
    adapter.enqueueJson(
      method: 'GET',
      path: '/media/rapid-uploads',
      body: <String, dynamic>{
        'items': [_batchJson(id: 1, state: 'completed', total: 3, ok: 3)],
        'page': 1,
        'page_size': 20,
        'total': 1,
      },
    );
    await container.read(mediaRapidUploadHistoryProvider.future);

    adapter.enqueueJson(
      method: 'GET',
      path: '/media/rapid-uploads/42',
      body: _batchWithItemsJson(id: 42, state: 'running', total: 2, ok: 0),
    );

    final detail = await container
        .read(mediaRapidUploadHistoryProvider.notifier)
        .refreshBatch(42);

    expect(detail.id, 42);
    final state =
        container.read(mediaRapidUploadHistoryProvider).requireValue;
    expect(state.items.first.id, 42);
    expect(state.items, hasLength(2));
    expect(state.total, 2);
  });

  test('refreshBatch upserts existing batch by id without changing total',
      () async {
    adapter.enqueueJson(
      method: 'GET',
      path: '/media/rapid-uploads',
      body: <String, dynamic>{
        'items': [_batchJson(id: 1, state: 'running', total: 3, ok: 0)],
        'page': 1,
        'page_size': 20,
        'total': 1,
      },
    );
    await container.read(mediaRapidUploadHistoryProvider.future);

    adapter.enqueueJson(
      method: 'GET',
      path: '/media/rapid-uploads/1',
      body: _batchWithItemsJson(id: 1, state: 'completed', total: 3, ok: 3),
    );

    await container
        .read(mediaRapidUploadHistoryProvider.notifier)
        .refreshBatch(1);

    final state =
        container.read(mediaRapidUploadHistoryProvider).requireValue;
    expect(state.items, hasLength(1));
    expect(state.items.single.state, MediaRapidUploadBatchState.completed);
    expect(state.total, 1);
  });
}

Map<String, dynamic> _batchJson({
  required int id,
  required String state,
  required int total,
  required int ok,
  int failed = 0,
  int cleanupFailed = 0,
}) {
  return <String, dynamic>{
    'id': id,
    'target_library_id': 8,
    'retry_of_batch_id': null,
    'task_run_id': 99,
    'state': state,
    'total_count': total,
    'succeeded_count': ok,
    'failed_count': failed,
    'cleanup_failed_count': cleanupFailed,
    'started_at': '2026-03-12T10:00:00Z',
    'finished_at': state == 'running' ? null : '2026-03-12T10:05:00Z',
    'created_at': '2026-03-12T09:59:00Z',
    'updated_at': '2026-03-12T10:05:00Z',
  };
}

Map<String, dynamic> _batchWithItemsJson({
  required int id,
  required String state,
  required int total,
  required int ok,
}) {
  final base = _batchJson(id: id, state: state, total: total, ok: ok);
  base['items'] = const <Map<String, dynamic>>[];
  return base;
}
