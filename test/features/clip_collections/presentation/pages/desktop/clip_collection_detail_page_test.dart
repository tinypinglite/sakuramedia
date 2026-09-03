import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' show ProviderScope;
import 'package:sakuramedia/core/session/providers/session_store_provider.dart';
import 'package:sakuramedia/features/clip_collections/presentation/providers/clip_collections_api_provider.dart';
import 'package:sakuramedia/features/clips/presentation/providers/clips_api_provider.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oktoast/oktoast.dart';
import 'package:sakuramedia/core/network/api_client.dart';
import 'package:sakuramedia/core/session/session_store.dart';
import 'package:sakuramedia/features/clip_collections/data/api/clip_collections_api.dart';
import 'package:sakuramedia/features/clip_collections/presentation/pages/desktop/clip_collection_detail_page.dart';
import 'package:sakuramedia/features/clips/data/api/clips_api.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/actions/app_button.dart';
import 'package:sakuramedia/widgets/base/navigation/app_filter_entry_button.dart';
import 'package:sakuramedia/widgets/base/navigation/app_list_header.dart';
import 'package:sakuramedia/widgets/base/feedback/app_cover_card_skeleton.dart';

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
        'name': '指奸潮吹',
        'description': '',
        'clip_count': total,
        'cover_image': null,
      },
    );
    adapter.enqueueJson(
      method: 'GET',
      path: '/clip-collections/1/clips',
      body: <String, dynamic>{
        // 成员是扁平结构：position 与切片字段同级。
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

  Future<void> pumpPage(WidgetTester tester, {bool settle = true}) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1280, 900);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sessionStoreProvider.overrideWithValue(sessionStore),
          clipCollectionsApiProvider.overrideWithValue(
            ClipCollectionsApi(apiClient: apiClient),
          ),
          clipsApiProvider.overrideWithValue(ClipsApi(apiClient: apiClient)),
        ],
        child: OKToast(
          child: MaterialApp(
            theme: sakuraThemeData,
            home: const Scaffold(
              body: DesktopClipCollectionDetailPage(collectionId: 1),
            ),
          ),
        ),
      ),
    );
    if (settle) {
      await tester.pumpAndSettle();
    } else {
      await tester.pump();
    }
  }

  testWidgets('首屏加载显示切片合集详情骨架', (tester) async {
    final pendingCollection = Completer<ResponseBody>();
    adapter.enqueueResponder(
      method: 'GET',
      path: '/clip-collections/1',
      responder: (_, __) => pendingCollection.future,
    );
    adapter.enqueueJson(
      method: 'GET',
      path: '/clip-collections/1/clips',
      body: const <String, dynamic>{
        'items': <dynamic>[],
        'page': 1,
        'page_size': 50,
        'total': 0,
      },
    );

    await pumpPage(tester, settle: false);

    expect(
      find.byKey(const Key('clip-collection-detail-loading')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('clip-collection-detail-skeleton-grid')),
      findsOneWidget,
    );
    expect(find.byType(AppCoverCardSkeleton), findsWidgets);
    expect(find.byType(CircularProgressIndicator), findsNothing);

    pendingCollection.complete(
      ResponseBody.fromString(
        '{"id":1,"name":"我的合集","description":"","clip_count":0,"cover_image":null}',
        200,
        headers: const <String, List<String>>{
          Headers.contentTypeHeader: <String>[Headers.jsonContentType],
        },
      ),
    );
    await tester.pumpAndSettle();
  });

  testWidgets('「播放全部」是 primary 按钮且贴右，与视频合集详情一致', (WidgetTester tester) async {
    enqueueInitialLoad();
    await pumpPage(tester);

    final playFinder = find.byKey(const Key('clip-collection-play-all-button'));
    final play = tester.widget<AppButton>(playFinder);
    expect(play.label, '播放全部');
    expect(play.variant, AppButtonVariant.primary);

    // 贴右：标题区必须整体 Expanded 吃掉剩余空间。写成
    // `Flexible(标题) + Spacer()` 会让两者平分剩余空间，按钮只到中间（真出过）。
    final playRect = tester.getRect(playFinder);
    final pageRect = tester.getRect(
      find.byKey(const Key('clip-collection-detail-page-body')),
    );
    expect(pageRect.right - playRect.right, lessThan(2));
  });

  testWidgets('空合集时「播放全部」禁用而不是隐藏', (WidgetTester tester) async {
    enqueueInitialLoad(total: 0);
    await pumpPage(tester);

    final play = tester.widget<AppButton>(
      find.byKey(const Key('clip-collection-play-all-button')),
    );
    expect(play.onPressed, isNull);
  });

  testWidgets('顶栏是 AppListHeader，无筛选维度所以不渲染筛选入口', (WidgetTester tester) async {
    enqueueInitialLoad();
    await pumpPage(tester);

    expect(find.byType(AppListHeader), findsOneWidget);
    expect(find.byType(AppFilterEntryButton), findsNothing);
    expect(find.text('2 个切片'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const Key('app-list-header-action-slots')),
        matching: find.byKey(const Key('clip-collection-add-clips-button')),
      ),
      findsOneWidget,
    );
  });
}
