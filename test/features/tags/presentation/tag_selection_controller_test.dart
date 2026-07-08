import 'package:flutter_test/flutter_test.dart';
import 'package:sakuramedia/core/network/api_client.dart';
import 'package:sakuramedia/core/session/session_store.dart';
import 'package:sakuramedia/features/movies/presentation/controllers/movie_filter_state.dart';
import 'package:sakuramedia/features/tags/data/tags_api.dart';
import 'package:sakuramedia/features/tags/presentation/tag_selection_controller.dart';

import '../../../support/fake_http_client_adapter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SessionStore sessionStore;
  late ApiClient apiClient;
  late TagsApi tagsApi;
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
    tagsApi = TagsApi(apiClient: apiClient);
    adapter = FakeHttpClientAdapter();
    apiClient.rawDio.httpClientAdapter = adapter;
    apiClient.rawRefreshDio.httpClientAdapter = adapter;
  });

  tearDown(() {
    apiClient.dispose();
  });

  void enqueueTags(List<Map<String, dynamic>> tags) {
    adapter.enqueueJson(
      method: 'GET',
      path: '/tags',
      statusCode: 200,
      body: tags,
    );
  }

  TagSelectionController buildController({int popularLimit = 60}) {
    return TagSelectionController(tagsApi: tagsApi, popularLimit: popularLimit);
  }

  test('load populates tags and marks hasLoadedOnce', () async {
    enqueueTags(<Map<String, dynamic>>[
      <String, dynamic>{'tag_id': 1, 'name': '巨乳', 'movie_count': 100},
      <String, dynamic>{'tag_id': 2, 'name': '单体作品', 'movie_count': 80},
    ]);
    final controller = buildController();

    await controller.load();

    expect(controller.hasLoadedOnce, isTrue);
    expect(controller.isLoading, isFalse);
    expect(controller.errorMessage, isNull);
    expect(controller.allTags, hasLength(2));
    addTearDown(controller.dispose);
  });

  test('visibleTags caps to popularLimit when not searching', () async {
    enqueueTags(<Map<String, dynamic>>[
      for (var i = 0; i < 10; i++)
        <String, dynamic>{'tag_id': i, 'name': 'tag$i', 'movie_count': 100 - i},
    ]);
    final controller = buildController(popularLimit: 3);

    await controller.load();

    expect(controller.visibleTags, hasLength(3));
    addTearDown(controller.dispose);
  });

  test('visibleTags filters by name substring when searching', () async {
    enqueueTags(<Map<String, dynamic>>[
      <String, dynamic>{'tag_id': 1, 'name': '巨乳', 'movie_count': 100},
      <String, dynamic>{'tag_id': 2, 'name': '美乳', 'movie_count': 80},
      <String, dynamic>{'tag_id': 3, 'name': '单体作品', 'movie_count': 60},
    ]);
    final controller = buildController(popularLimit: 1);

    await controller.load();
    controller.setQuery('乳');

    expect(controller.isSearching, isTrue);
    expect(
      controller.visibleTags.map((tag) => tag.tagId),
      containsAll(<int>[1, 2]),
    );
    expect(controller.visibleTags.any((tag) => tag.tagId == 3), isFalse);
    addTearDown(controller.dispose);
  });

  test('toggle and clear manage selection in order', () async {
    enqueueTags(<Map<String, dynamic>>[
      <String, dynamic>{'tag_id': 1, 'name': 'a', 'movie_count': 10},
      <String, dynamic>{'tag_id': 2, 'name': 'b', 'movie_count': 9},
    ]);
    final controller = buildController();

    await controller.load();
    controller.toggle(2);
    controller.toggle(1);

    expect(controller.selectedTagIds, <int>[2, 1]);
    expect(controller.hasSelection, isTrue);

    controller.toggle(2);
    expect(controller.selectedTagIds, <int>[1]);

    controller.clear();
    expect(controller.hasSelection, isFalse);
    addTearDown(controller.dispose);
  });

  test('setMatchMode defaults to or and notifies only on change', () async {
    enqueueTags(<Map<String, dynamic>>[
      <String, dynamic>{'tag_id': 1, 'name': 'a', 'movie_count': 10},
    ]);
    final controller = buildController();
    await controller.load();

    expect(controller.matchMode, TagMatchMode.or);

    var notifications = 0;
    controller.addListener(() => notifications++);

    controller.setMatchMode(TagMatchMode.and);
    expect(controller.matchMode, TagMatchMode.and);
    expect(notifications, 1);

    controller.setMatchMode(TagMatchMode.and);
    expect(notifications, 1);

    addTearDown(controller.dispose);
  });
}
