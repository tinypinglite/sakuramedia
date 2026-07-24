import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oktoast/oktoast.dart';
import 'package:provider/provider.dart';
import 'package:sakuramedia/core/network/api_client.dart';
import 'package:sakuramedia/core/session/session_store.dart';
import 'package:sakuramedia/features/shared/presentation/collection_playback_handoff.dart';
import 'package:sakuramedia/features/videos/data/api/video_collections_api.dart';
import 'package:sakuramedia/features/videos/data/api/videos_api.dart';
import 'package:sakuramedia/features/videos/presentation/controllers/notifiers/video_mutation_change_notifier.dart';
import 'package:sakuramedia/features/videos/presentation/pages/mobile/video_collection_detail_page.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/navigation/app_filter_entry_button.dart';
import 'package:sakuramedia/widgets/base/navigation/app_list_header.dart';
import 'package:sakuramedia/widgets/shell/mobile/app_mobile_subpage_shell.dart';

import '../../../../../support/fake_http_client_adapter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

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

  void enqueueInitialLoad({int total = 3}) {
    adapter.enqueueJson(
      method: 'GET',
      path: '/video-collections/1',
      body: <String, dynamic>{
        'id': 1,
        'name': '我的合集',
        'description': '',
        'item_count': total,
        'cover_image': null,
      },
    );
    adapter.enqueueJson(
      method: 'GET',
      path: '/video-collections/1/items',
      body: <String, dynamic>{
        'items': <Map<String, dynamic>>[
          for (var i = 0; i < total; i++)
            <String, dynamic>{
              'item_id': i + 1,
              'position': i,
              'video': <String, dynamic>{
                'id': i + 1,
                'title': '视频 $i',
                'summary': '',
                'cover_image': null,
                'release_date': null,
                'duration_seconds': 60,
                'file_size_bytes': 100,
                'media_count': 1,
                'can_play': true,
                'collections': <Map<String, dynamic>>[],
                'created_at': null,
                'updated_at': null,
              },
            },
        ],
        'page': 1,
        'page_size': 100,
        'total': total,
      },
    );
  }

  Future<void> pumpPage(WidgetTester tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<SessionStore>.value(value: sessionStore),
          Provider<VideosApi>.value(value: VideosApi(apiClient: apiClient)),
          Provider<VideoCollectionsApi>.value(
            value: VideoCollectionsApi(apiClient: apiClient),
          ),
          ChangeNotifierProvider(create: (_) => VideoMutationChangeNotifier()),
          Provider(create: (_) => CollectionPlaybackHandoff()),
        ],
        child: OKToast(
          child: MaterialApp(
            theme: sakuraThemeData,
            // 真实路由把页面套在这个壳里（见 _MobileSubpageRouteData.buildPage）。
            home: const AppMobileSubpageShell(
              title: '合集',
              defaultLocation: '/mobile/library/video-collections',
              child: MobileVideoCollectionDetailPage(collectionId: 1),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('合集名报到返回栏，页面内不再重复标题', (WidgetTester tester) async {
    enqueueInitialLoad();
    await pumpPage(tester);

    // 返回栏标题从静态「合集」换成真实合集名，页面里不再另写一个大标题。
    expect(
      tester.widget<Text>(find.byKey(const Key('mobile-subpage-title'))).data,
      '我的合集',
    );
    expect(find.text('合集'), findsNothing);
    expect(find.text('我的合集'), findsOneWidget);

    // 顶栏紧接在返回栏下方，中间没有被标题块顶开。
    final header = tester.getRect(find.byType(AppListHeader));
    final bodyPadding = tester.getRect(
      find.byKey(const Key('mobile-subpage-body-padding')),
    );
    expect(header.top - bodyPadding.top, lessThan(16));

    expect(
      find.descendant(
        of: find.byKey(const Key('app-list-header-information-slots')),
        matching: find.byKey(const Key('mobile-video-collection-total')),
      ),
      findsOneWidget,
    );
    expect(find.text('3 个视频'), findsOneWidget);
  });

  testWidgets('排序走底部抽屉，摘要默认是手动顺序', (WidgetTester tester) async {
    enqueueInitialLoad();
    await pumpPage(tester);

    expect(
      tester
          .widget<AppFilterEntryButton>(find.byType(AppFilterEntryButton))
          .label,
      '手动顺序',
    );

    await tester.tap(
      find.byKey(const Key('mobile-video-collection-sort-trigger')),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('mobile-video-collection-sort-drawer')),
      findsOneWidget,
    );
    // 面板与桌面浮层同构：手动顺序 + 各排序字段，手动顺序下隐藏方向分节。
    expect(
      find.byKey(const Key('video-collection-sort-manual')),
      findsOneWidget,
    );
    expect(find.text('升降序'), findsNothing);

    adapter.enqueueJson(
      method: 'GET',
      path: '/video-collections/1/items',
      body: <String, dynamic>{
        'items': <Map<String, dynamic>>[],
        'page': 1,
        'page_size': 100,
        'total': 0,
      },
    );

    await tester.tap(find.byKey(const Key('video-collection-sort-title')));
    await tester.pumpAndSettle();

    // 即时生效：点选当场带 sort 重新拉取成员。
    final lastRequest = adapter.requests.last;
    expect(lastRequest.path, '/video-collections/1/items');
    expect(lastRequest.uri.queryParameters['sort'], startsWith('title:'));
  });
}
