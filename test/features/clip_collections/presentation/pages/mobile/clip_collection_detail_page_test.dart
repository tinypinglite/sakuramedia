import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oktoast/oktoast.dart';
import 'package:provider/provider.dart';
import 'package:sakuramedia/core/network/api_client.dart';
import 'package:sakuramedia/core/session/session_store.dart';
import 'package:sakuramedia/features/clip_collections/data/api/clip_collections_api.dart';
import 'package:sakuramedia/features/clip_collections/presentation/pages/mobile/clip_collection_detail_page.dart';
import 'package:sakuramedia/features/clips/data/api/clips_api.dart';
import 'package:sakuramedia/features/clips/presentation/controllers/clip_mutation_change_notifier.dart';
import 'package:sakuramedia/features/shared/presentation/collection_playback_handoff.dart';
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

  void enqueueInitialLoad({int total = 2}) {
    adapter.enqueueJson(
      method: 'GET',
      path: '/clip-collections/1',
      body: <String, dynamic>{
        'id': 1,
        'name': '很长很长的切片合集名称',
        'description': '',
        'clip_count': total,
        'cover_image': null,
      },
    );
    adapter.enqueueJson(
      method: 'GET',
      path: '/clip-collections/1/clips',
      body: <String, dynamic>{
        // 成员是扁平结构：ClipCollectionClipItemDto.fromJson 直接把外层 json
        // 喂给 MediaClipDto.fromJson，position 与切片字段同级。
        'items': <Map<String, dynamic>>[
          for (var i = 0; i < total; i++)
            <String, dynamic>{
              'position': i,
              'clip_id': i + 1,
              'media_id': 100 + i,
              'movie_number': 'ABC-00${i + 1}',
              'start_offset_seconds': 0,
              'end_offset_seconds': 30,
              'title': '切片 $i',
              'duration_seconds': 30,
              'file_size_bytes': 100,
              'cover_image': null,
              'stream_url': 'https://example.com/$i.mp4',
              'created_at': null,
              'preview_frames': <dynamic>[],
              'collections': <dynamic>[],
            },
        ],
        'page': 1,
        'page_size': 50,
        'total': total,
      },
    );
  }

  Future<void> pumpPage(WidgetTester tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(374, 844);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<SessionStore>.value(value: sessionStore),
          Provider<ClipCollectionsApi>.value(
            value: ClipCollectionsApi(apiClient: apiClient),
          ),
          Provider<ClipsApi>.value(value: ClipsApi(apiClient: apiClient)),
          ChangeNotifierProvider(create: (_) => ClipMutationChangeNotifier()),
          Provider(create: (_) => CollectionPlaybackHandoff()),
        ],
        child: OKToast(
          child: MaterialApp(
            theme: sakuraThemeData,
            // 真实路由把页面套在这个壳里（见 _MobileSubpageRouteData.buildPage）。
            home: const AppMobileSubpageShell(
              title: '合集',
              defaultLocation: '/mobile/library/clip-collections',
              child: MobileClipCollectionDetailPage(collectionId: 1),
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

    expect(
      tester.widget<Text>(find.byKey(const Key('mobile-subpage-title'))).data,
      '很长很长的切片合集名称',
    );
    expect(find.text('合集'), findsNothing);
    // 页面里不再有第二个标题，切片数落在顶栏信息槽。
    expect(find.text('很长很长的切片合集名称'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const Key('app-list-header-information-slots')),
        matching: find.byKey(const Key('mobile-clip-collection-total')),
      ),
      findsOneWidget,
    );
    expect(find.text('2 个切片'), findsOneWidget);
  });

  testWidgets('顶栏无筛选入口、不常驻「选择」，长按卡片进多选', (WidgetTester tester) async {
    enqueueInitialLoad();
    await pumpPage(tester);

    // 切片合集是手动顺序，没有排序参数，所以没有筛选入口。
    expect(find.byType(AppListHeader), findsOneWidget);
    expect(find.byType(AppFilterEntryButton), findsNothing);
    // 长按即可进多选，顶栏不必再放一个「选择」。
    expect(
      find.byKey(const Key('mobile-clip-collection-enter-selection-button')),
      findsNothing,
    );

    // 移动端默认网格布局，卡片挂 ValueKey(clipId)。
    await tester.longPress(find.byKey(const ValueKey<int>(1)));
    await tester.pumpAndSettle();

    // 顶栏原地改写为计数 + 全选；批量动作在贴底的操作条里。
    expect(
      find.byKey(const Key('app-list-header-selection-label')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('mobile-clip-collection-batch-bottom-bar')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
}
