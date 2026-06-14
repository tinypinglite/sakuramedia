import 'package:flutter_test/flutter_test.dart';
import 'package:sakuramedia/core/network/api_client.dart';
import 'package:sakuramedia/core/session/session_store.dart';
import 'package:sakuramedia/features/videos/data/videos_api.dart';
import 'package:sakuramedia/features/videos/presentation/video_list_page_state.dart';
import 'package:sakuramedia/features/videos/presentation/video_mutation_change_notifier.dart';

import '../../../support/fake_http_client_adapter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SessionStore sessionStore;
  late ApiClient apiClient;
  late VideosApi videosApi;
  late FakeHttpClientAdapter adapter;
  late VideoMutationChangeNotifier notifier;

  setUp(() async {
    sessionStore = SessionStore.inMemory();
    await sessionStore.saveBaseUrl('https://api.example.com');
    await sessionStore.saveTokens(
      accessToken: 'access-token',
      refreshToken: 'refresh-token',
      expiresAt: DateTime.parse('2026-03-08T10:00:00Z'),
    );
    apiClient = ApiClient(sessionStore: sessionStore);
    videosApi = VideosApi(apiClient: apiClient);
    adapter = FakeHttpClientAdapter();
    apiClient.rawDio.httpClientAdapter = adapter;
    apiClient.rawRefreshDio.httpClientAdapter = adapter;
    notifier = VideoMutationChangeNotifier();
  });

  tearDown(() {
    apiClient.dispose();
  });

  Map<String, dynamic> videoItem(int id, String title) => <String, dynamic>{
    'id': id,
    'title': title,
    'summary': '',
    'cover_image': null,
    'release_date': null,
    'media_count': 1,
    'can_play': true,
    'created_at': '2026-01-02T03:04:05',
    'updated_at': '2026-01-02T03:04:05',
  };

  void enqueueTwoItems() {
    adapter.enqueueJson(
      method: 'GET',
      path: '/videos',
      body: <String, dynamic>{
        'items': <dynamic>[videoItem(1, '视频一'), videoItem(2, '视频二')],
        'page': 1,
        'page_size': 24,
        'total': 2,
      },
    );
  }

  test('收到 deleted 信号后从分页列表精准移除对应项', () async {
    enqueueTwoItems();
    final entry = VideoListPageStateEntry(
      videosApi: videosApi,
      mutationNotifier: notifier,
    );
    addTearDown(entry.dispose);
    await pumpEventQueue();

    expect(entry.controller.items.map((item) => item.id), <int>[1, 2]);
    expect(entry.controller.total, 2);

    notifier.reportDeleted(1);

    expect(entry.controller.items.map((item) => item.id), <int>[2]);
    expect(entry.controller.total, 1);
  });

  test('合集成员变更信号不影响视频网格', () async {
    enqueueTwoItems();
    final entry = VideoListPageStateEntry(
      videosApi: videosApi,
      mutationNotifier: notifier,
    );
    addTearDown(entry.dispose);
    await pumpEventQueue();

    notifier.reportCollectionMembershipChanged(videoId: 1, collectionId: 9);

    expect(entry.controller.items.map((item) => item.id), <int>[1, 2]);
    expect(entry.controller.total, 2);
  });

  test('dispose 后解绑监听，信号不再触发移除', () async {
    enqueueTwoItems();
    final entry = VideoListPageStateEntry(
      videosApi: videosApi,
      mutationNotifier: notifier,
    );
    await pumpEventQueue();
    expect(entry.controller.items.map((item) => item.id), <int>[1, 2]);

    entry.dispose();
    // dispose 已 removeListener；再发信号不应抛错或改动（控制器已 dispose）。
    notifier.reportDeleted(1);
  });
}
