import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sakuramedia/core/network/api_client.dart';
import 'package:sakuramedia/core/session/session_store.dart';
import 'package:sakuramedia/features/actors/data/api/actors_api.dart';
import 'package:sakuramedia/features/actors/presentation/providers/actor_tag_filter_provider.dart';
import 'package:sakuramedia/features/actors/presentation/providers/actors_api_provider.dart';
import 'package:sakuramedia/features/movies/presentation/controllers/listing/movie_filter_state.dart';

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
      expiresAt: DateTime.parse('2026-11-06T12:00:00Z'),
    );
    apiClient = ApiClient(sessionStore: sessionStore);
    adapter = FakeHttpClientAdapter();
    apiClient.rawDio.httpClientAdapter = adapter;
    apiClient.rawRefreshDio.httpClientAdapter = adapter;
    container = ProviderContainer(
      overrides: [
        actorsApiProvider.overrideWithValue(ActorsApi(apiClient: apiClient)),
      ],
      retry: (_, _) => null,
    );
    container.listen(actorTagFilterProvider(7), (_, _) {});
  });

  tearDown(() {
    container.dispose();
    apiClient.dispose();
    sessionStore.dispose();
  });

  test('标签数据懒加载，选择与匹配模式独立保留', () async {
    final provider = actorTagFilterProvider(7);
    expect(container.read(provider).hasLoadedOnce, isFalse);
    expect(adapter.requests, isEmpty);

    adapter.enqueueJson(
      method: 'GET',
      path: '/actors/7/tags',
      body: <Map<String, dynamic>>[
        <String, dynamic>{'tag_id': 5, 'name': '单体作品', 'movie_count': 8},
        <String, dynamic>{'tag_id': 3, 'name': '巨乳', 'movie_count': 12},
      ],
    );

    await container.read(provider.notifier).load();

    var state = container.read(provider);
    expect(state.hasLoadedOnce, isTrue);
    expect(state.allTags.map((tag) => tag.movieCount), <int>[12, 8]);
    expect(state.allTags.map((tag) => tag.name), <String>['巨乳', '单体作品']);
    expect(adapter.requests.single.path, '/actors/7/tags');

    container.read(provider.notifier).toggle(3);
    container.read(provider.notifier).setMatchMode(TagMatchMode.and);
    state = container.read(provider);
    expect(state.selectedTagIds, <int>[3]);
    expect(state.matchMode, TagMatchMode.and);
    expect(state.selectedTags.single.name, '巨乳');

    container.read(provider.notifier).clear();
    expect(container.read(provider).hasSelection, isFalse);
  });
}
