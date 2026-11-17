import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sakuramedia/core/network/api_client.dart';
import 'package:sakuramedia/core/session/session_store.dart';
import 'package:sakuramedia/features/movies/presentation/controllers/listing/movie_filter_state.dart';
import 'package:sakuramedia/features/tags/data/tags_api.dart';
import 'package:sakuramedia/features/tags/presentation/providers/tag_selection_provider.dart';
import 'package:sakuramedia/features/tags/presentation/providers/tag_selection_scope.dart';
import 'package:sakuramedia/features/tags/presentation/providers/tags_api_provider.dart';

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
      expiresAt: DateTime.parse('2026-08-10T12:00:00Z'),
    );
    apiClient = ApiClient(sessionStore: sessionStore);
    adapter = FakeHttpClientAdapter();
    apiClient.rawDio.httpClientAdapter = adapter;
    apiClient.rawRefreshDio.httpClientAdapter = adapter;
    container = ProviderContainer(
      overrides: [
        tagsApiProvider.overrideWithValue(TagsApi(apiClient: apiClient)),
      ],
    );
  });

  tearDown(() {
    container.dispose();
    apiClient.dispose();
    sessionStore.dispose();
  });

  void enqueueTags(List<Map<String, dynamic>> tags, {int statusCode = 200}) {
    adapter.enqueueJson(
      method: 'GET',
      path: '/tags',
      statusCode: statusCode,
      body: tags,
    );
  }

  Future<void> waitForLoad(TagSelectionScope scope) async {
    for (var index = 0; index < 12; index += 1) {
      final state = container.read(tagSelectionProvider(scope));
      if (state.hasLoadedOnce || state.errorMessage != null) {
        return;
      }
      await Future<void>.delayed(Duration.zero);
    }
    fail('tag selection did not finish loading');
  }

  test('初始加载填充标签并标记 hasLoadedOnce', () async {
    const scope = TagSelectionScope.custom(instanceKey: 'load');
    enqueueTags(<Map<String, dynamic>>[
      <String, dynamic>{'tag_id': 1, 'name': '巨乳', 'movie_count': 100},
      <String, dynamic>{'tag_id': 2, 'name': '单体作品', 'movie_count': 80},
    ]);
    container.listen(tagSelectionProvider(scope), (_, __) {});
    await waitForLoad(scope);

    final state = container.read(tagSelectionProvider(scope));
    expect(state.hasLoadedOnce, isTrue);
    expect(state.isLoading, isFalse);
    expect(state.errorMessage, isNull);
    expect(state.allTags, hasLength(2));
  });

  test('搜索在全部标签里过滤，不做数量截断', () async {
    const scope = TagSelectionScope.custom(instanceKey: 'visible');
    enqueueTags(<Map<String, dynamic>>[
      for (var index = 0; index < 10; index += 1)
        <String, dynamic>{
          'tag_id': index,
          'name': index < 2 ? '乳$index' : 'tag$index',
          'movie_count': 100 - index,
        },
    ]);
    container.listen(tagSelectionProvider(scope), (_, __) {});
    await waitForLoad(scope);

    expect(
      container.read(tagSelectionProvider(scope)).filteredTags,
      hasLength(10),
    );
    container.read(tagSelectionProvider(scope).notifier).setQuery('乳');
    final state = container.read(tagSelectionProvider(scope));
    expect(state.isSearching, isTrue);
    expect(state.filteredTags.map((tag) => tag.tagId), <int>[0, 1]);
  });

  test('选择顺序、清空与 match mode 只写不可变 state', () async {
    const scope = TagSelectionScope.custom(instanceKey: 'selection');
    enqueueTags(<Map<String, dynamic>>[
      <String, dynamic>{'tag_id': 1, 'name': 'a', 'movie_count': 10},
      <String, dynamic>{'tag_id': 2, 'name': 'b', 'movie_count': 9},
    ]);
    container.listen(tagSelectionProvider(scope), (_, __) {});
    await waitForLoad(scope);
    final notifier = container.read(tagSelectionProvider(scope).notifier);

    notifier
      ..toggle(2)
      ..toggle(1)
      ..setMatchMode(TagMatchMode.and);
    expect(container.read(tagSelectionProvider(scope)).selectedTagIds, <int>[
      2,
      1,
    ]);
    expect(
      container.read(tagSelectionProvider(scope)).matchMode,
      TagMatchMode.and,
    );

    notifier.toggle(2);
    expect(container.read(tagSelectionProvider(scope)).selectedTagIds, <int>[
      1,
    ]);

    notifier.replaceSelection(<int>[2], matchMode: TagMatchMode.or);
    expect(container.read(tagSelectionProvider(scope)).selectedTagIds, <int>[
      2,
    ]);
    expect(
      container.read(tagSelectionProvider(scope)).matchMode,
      TagMatchMode.or,
    );

    notifier.clear();
    expect(container.read(tagSelectionProvider(scope)).hasSelection, isFalse);
  });

  test('失败保留错误，retry 成功后恢复数据', () async {
    const scope = TagSelectionScope.custom(instanceKey: 'retry');
    enqueueTags(const <Map<String, dynamic>>[], statusCode: 500);
    container.listen(tagSelectionProvider(scope), (_, __) {});
    await waitForLoad(scope);
    expect(container.read(tagSelectionProvider(scope)).errorMessage, isNotNull);

    enqueueTags(<Map<String, dynamic>>[
      <String, dynamic>{'tag_id': 1, 'name': 'a', 'movie_count': 10},
    ]);
    await container.read(tagSelectionProvider(scope).notifier).retry();
    final state = container.read(tagSelectionProvider(scope));
    expect(state.errorMessage, isNull);
    expect(state.allTags.single.tagId, 1);
  });

  test('preload=false 构建不请求标签，显式 load 后才拉取', () async {
    const scope = TagSelectionScope.custom(instanceKey: 'lazy', preload: false);
    enqueueTags(<Map<String, dynamic>>[
      <String, dynamic>{'tag_id': 1, 'name': '巨乳', 'movie_count': 10},
    ]);
    container.listen(tagSelectionProvider(scope), (_, __) {});
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);

    expect(adapter.requests, isEmpty);
    expect(container.read(tagSelectionProvider(scope)).hasLoadedOnce, isFalse);

    await container.read(tagSelectionProvider(scope).notifier).load();
    expect(container.read(tagSelectionProvider(scope)).allTags, hasLength(1));
  });
}
