import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sakuramedia/core/network/api_client.dart';
import 'package:sakuramedia/core/network/providers/api_client_provider.dart';
import 'package:sakuramedia/core/session/providers/session_store_provider.dart';
import 'package:sakuramedia/core/session/session_store.dart';
import 'package:sakuramedia/features/media/data/media_tag_dto.dart';
import 'package:sakuramedia/features/media/presentation/providers/media_tags_provider.dart';

import '../../../../support/fake_http_client_adapter.dart';

void main() {
  late SessionStore sessionStore;
  late ApiClient apiClient;
  late FakeHttpClientAdapter adapter;
  late ProviderContainer container;

  setUp(() async {
    sessionStore = SessionStore.inMemory();
    await sessionStore.saveBaseUrl('https://api.example.com');
    await sessionStore.saveTokens(
      accessToken: 'access-token',
      refreshToken: 'refresh-token',
      expiresAt: DateTime.parse('2026-10-31T12:00:00Z'),
    );
    apiClient = ApiClient(sessionStore: sessionStore);
    adapter = FakeHttpClientAdapter();
    apiClient.rawDio.httpClientAdapter = adapter;
    apiClient.rawRefreshDio.httpClientAdapter = adapter;
    container = ProviderContainer(
      overrides: [
        apiClientProvider.overrideWithValue(apiClient),
        sessionStoreProvider.overrideWithValue(sessionStore),
      ],
      retry: (_, _) => null,
    );
  });

  tearDown(() {
    container.dispose();
    apiClient.dispose();
    sessionStore.dispose();
  });

  test('loads and keeps the local list in sync through CRUD', () async {
    adapter.enqueueJson(
      method: 'GET',
      path: '/media-tags',
      body: <Map<String, dynamic>>[_tagJson(1, '4K', mediaCount: 5)],
    );

    final initial = await container.read(mediaTagsProvider.future);
    expect(initial.single.name, '4K');

    adapter.enqueueJson(
      method: 'POST',
      path: '/media-tags',
      statusCode: 201,
      body: _tagJson(2, 'Subtitles', mediaCount: 0),
    );
    await container
        .read(mediaTagsProvider.notifier)
        .create(
          const MediaTagUpsertPayload(
            name: 'Subtitles',
            includeTerms: ['CHS'],
            excludeTerms: [],
            enabled: true,
          ),
        );
    expect(
      container.read(mediaTagsProvider).requireValue.map((tag) => tag.id),
      [1, 2],
    );

    adapter.enqueueJson(
      method: 'PUT',
      path: '/media-tags/2',
      body: _tagJson(2, 'Subtitles', mediaCount: 9, enabled: false),
    );
    await container
        .read(mediaTagsProvider.notifier)
        .updateTag(
          tagId: 2,
          payload: const MediaTagUpsertPayload(
            name: 'Subtitles',
            includeTerms: ['CHS'],
            excludeTerms: [],
            enabled: false,
          ),
        );
    final updated = container.read(mediaTagsProvider).requireValue;
    expect(updated.first.id, 2);
    expect(updated.first.mediaCount, 9);
    expect(updated.first.enabled, isFalse);

    adapter.enqueueJson(
      method: 'DELETE',
      path: '/media-tags/2',
      statusCode: 204,
      body: null,
    );
    await container.read(mediaTagsProvider.notifier).delete(2);
    expect(
      container.read(mediaTagsProvider).requireValue.map((tag) => tag.id),
      [1],
    );
  });

  test('列表加载失败后新建的规则不会被丢弃', () async {
    // 首次加载失败：列表没有可用值。
    adapter.enqueueJson(
      method: 'GET',
      path: '/media-tags',
      statusCode: 500,
      body: <String, dynamic>{
        'error': <String, dynamic>{'code': 'boom', 'message': 'boom'},
      },
    );
    await expectLater(
      container.read(mediaTagsProvider.future),
      throwsA(isA<Object>()),
    );
    expect(container.read(mediaTagsProvider).hasError, isTrue);

    // 错误态下新建：保存成功后要重新拉取列表，新规则要能看到。
    adapter.enqueueJson(
      method: 'POST',
      path: '/media-tags',
      statusCode: 201,
      body: _tagJson(2, 'Subtitles', mediaCount: 0),
    );
    adapter.enqueueJson(
      method: 'GET',
      path: '/media-tags',
      body: <Map<String, dynamic>>[_tagJson(2, 'Subtitles', mediaCount: 0)],
    );
    await container
        .read(mediaTagsProvider.notifier)
        .create(
          const MediaTagUpsertPayload(
            name: 'Subtitles',
            includeTerms: ['CHS'],
            excludeTerms: [],
            enabled: true,
          ),
        );
    await container.read(mediaTagsProvider.future);

    expect(
      container.read(mediaTagsProvider).requireValue.map((tag) => tag.id),
      [2],
    );
  });
}

Map<String, dynamic> _tagJson(
  int id,
  String name, {
  required int mediaCount,
  bool enabled = true,
}) {
  return <String, dynamic>{
    'id': id,
    'name': name,
    'include_terms': [name.toLowerCase()],
    'exclude_terms': <dynamic>[],
    'enabled': enabled,
    'media_count': mediaCount,
    'created_at': '2026-10-31T01:02:03Z',
    'updated_at': '2026-10-31T01:02:03Z',
  };
}
