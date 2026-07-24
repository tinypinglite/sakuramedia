import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oktoast/oktoast.dart';
import 'package:provider/provider.dart';
import 'package:sakuramedia/core/network/api_client.dart';
import 'package:sakuramedia/core/session/session_store.dart';
import 'package:sakuramedia/features/videos/data/api/video_collections_api.dart';
import 'package:sakuramedia/features/videos/data/api/videos_api.dart';
import 'package:sakuramedia/features/videos/presentation/controllers/notifiers/video_mutation_change_notifier.dart';
import 'package:sakuramedia/features/videos/presentation/pages/desktop/video_list_page.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/interaction/selection/app_selection_toolbar.dart';
import 'package:sakuramedia/widgets/base/layout/scrolling/app_filter_total_header.dart';
import 'package:sakuramedia/widgets/base/navigation/app_filter_entry_button.dart';
import 'package:sakuramedia/widgets/base/navigation/app_list_header.dart';

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

  void enqueueInitialLoad({int total = 2}) {
    adapter.enqueueJson(
      method: 'GET',
      path: '/video-collections',
      body: <Map<String, dynamic>>[],
    );
    adapter.enqueueJson(
      method: 'GET',
      path: '/videos',
      body: _videosJson(total: total),
    );
  }

  testWidgets('桌面 PornBox 顶栏与移动端同构：筛选入口 + 总数 + 选择入口', (
    WidgetTester tester,
  ) async {
    enqueueInitialLoad();

    await _pumpVideoListPage(tester, sessionStore: sessionStore, apiClient: apiClient);
    await tester.pumpAndSettle();

    // 顶栏收敛到 AppListHeader，旧的 AppFilterTotalHeader 不再出现。
    expect(find.byType(AppListHeader), findsOneWidget);
    expect(find.byType(AppFilterTotalHeader), findsNothing);

    // 筛选入口与移动端共用同一个按钮，摘要报当前排序字段。
    final entry = tester.widget<AppFilterEntryButton>(
      find.byType(AppFilterEntryButton),
    );
    expect(entry.label, isNotNull);

    // 总数走只读信息胶囊；「选择」在右侧操作槽。
    expect(find.byKey(const Key('videos-page-total')), findsOneWidget);
    expect(find.text('2 个'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const Key('app-list-header-action-slots')),
        matching: find.byKey(const Key('videos-enter-selection-button')),
      ),
      findsOneWidget,
    );
  });

  testWidgets('进入多选原地改写整条顶栏，不另起一行且高度不变', (WidgetTester tester) async {
    enqueueInitialLoad();

    await _pumpVideoListPage(tester, sessionStore: sessionStore, apiClient: apiClient);
    await tester.pumpAndSettle();

    final headerHeight =
        tester.getSize(find.byType(AppListHeader).first).height;

    await tester.tap(find.byKey(const Key('videos-enter-selection-button')));
    await tester.pumpAndSettle();

    // 常规顶栏被替换掉，而不是在它下方再加一行。
    expect(find.byType(AppListHeader), findsNothing);
    expect(find.byType(AppSelectionHeaderToolbar), findsOneWidget);
    expect(find.byKey(const Key('videos-select-all-button')), findsOneWidget);
    expect(
      find.byKey(const Key('videos-batch-add-collection-button')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('videos-batch-delete-button')), findsOneWidget);

    // 进出多选不跳版：两态高度一致（与影片列表同一条规则）。
    expect(
      tester.getSize(find.byType(AppSelectionHeaderToolbar)).height,
      headerHeight,
    );

    await tester.tap(find.byKey(const Key('videos-exit-selection-button')));
    await tester.pumpAndSettle();

    expect(find.byType(AppListHeader), findsOneWidget);
    expect(find.byType(AppSelectionHeaderToolbar), findsNothing);
  });

  testWidgets('桌面筛选浮层与移动抽屉同构，点选排序即时生效', (WidgetTester tester) async {
    enqueueInitialLoad();

    await _pumpVideoListPage(tester, sessionStore: sessionStore, apiClient: apiClient);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('videos-filter-trigger')));
    await tester.pumpAndSettle();

    // 面板内容与移动抽屉逐节一致（排序字段 + 升降序）。
    expect(find.byKey(const Key('videos-filter-panel')), findsOneWidget);
    expect(find.text('排序字段'), findsOneWidget);
    expect(find.text('升降序'), findsOneWidget);
    expect(find.text('确定'), findsNothing);

    adapter.enqueueJson(
      method: 'GET',
      path: '/videos',
      body: _videosJson(total: 1),
    );

    await tester.tap(find.byKey(const Key('videos-filter-sort-title')));
    await tester.pumpAndSettle();

    // 即时生效：点选当场触发带新排序的重新拉取。
    final lastRequest = adapter.requests.last;
    expect(lastRequest.path, '/videos');
    expect(lastRequest.uri.queryParameters['sort'], startsWith('title:'));
    expect(find.text('1 个'), findsOneWidget);
  });
}

Future<void> _pumpVideoListPage(
  WidgetTester tester, {
  required SessionStore sessionStore,
  required ApiClient apiClient,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(1280, 1400);
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
        ChangeNotifierProvider<VideoMutationChangeNotifier>(
          create: (_) => VideoMutationChangeNotifier(),
        ),
      ],
      child: OKToast(
        child: MaterialApp(
          theme: sakuraThemeData,
          home: const Scaffold(body: DesktopVideoListPage()),
        ),
      ),
    ),
  );
}

Map<String, dynamic> _videosJson({
  int page = 1,
  int pageSize = 20,
  int total = 2,
}) {
  return <String, dynamic>{
    'items': <Map<String, dynamic>>[
      for (var index = 0; index < total; index++) _videoItem(id: index + 1),
    ],
    'page': page,
    'page_size': pageSize,
    'total': total,
  };
}

Map<String, dynamic> _videoItem({int id = 1}) {
  return <String, dynamic>{
    'id': id,
    'title': '视频 $id',
    'summary': '',
    'cover_image': null,
    'release_date': null,
    'duration_seconds': 0,
    'file_size_bytes': 0,
    'media_count': 1,
    'can_play': true,
    'collections': <Map<String, dynamic>>[],
    'created_at': null,
    'updated_at': null,
  };
}
