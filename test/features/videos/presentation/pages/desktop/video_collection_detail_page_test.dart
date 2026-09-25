import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/gestures.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' show ProviderScope;
import 'package:sakuramedia/core/session/providers/session_store_provider.dart';
import 'package:sakuramedia/features/videos/presentation/providers/videos_api_provider.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oktoast/oktoast.dart';
import 'package:sakuramedia/core/network/api_client.dart';
import 'package:sakuramedia/core/session/session_store.dart';
import 'package:sakuramedia/features/videos/data/api/video_collections_api.dart';
import 'package:sakuramedia/features/videos/data/api/videos_api.dart';
import 'package:sakuramedia/features/videos/presentation/pages/desktop/video_collection_detail_page.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/feedback/app_skeletonizer.dart';
import 'package:sakuramedia/widgets/domain/collections/collection_member_views.dart';

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
        'description': '简介内容',
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

  Future<void> pumpPage(WidgetTester tester, {bool settle = true}) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1200, 800);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sessionStoreProvider.overrideWithValue(sessionStore),
          videosApiProvider.overrideWithValue(VideosApi(apiClient: apiClient)),
          videoCollectionsApiProvider.overrideWithValue(
            VideoCollectionsApi(apiClient: apiClient),
          ),
        ],
        child: OKToast(
          child: MaterialApp(
            theme: sakuraThemeData,
            home: const Scaffold(
              body: DesktopVideoCollectionDetailPage(collectionId: 1),
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

  testWidgets('首屏加载用占位数据渲染真实布局并灰化', (tester) async {
    final pendingCollection = Completer<ResponseBody>();
    adapter.enqueueResponder(
      method: 'GET',
      path: '/video-collections/1',
      responder: (_, __) => pendingCollection.future,
    );
    adapter.enqueueJson(
      method: 'GET',
      path: '/video-collections/1/items',
      body: const <String, dynamic>{
        'items': <dynamic>[],
        'page': 1,
        'page_size': 100,
        'total': 0,
      },
    );

    await pumpPage(tester, settle: false);

    expect(find.byType(AppSkeletonizer), findsOneWidget);
    expect(
      find.byKey(const Key('video-collection-detail-grid')),
      findsOneWidget,
    );
    // 加载态渲染的是真实成员卡片（占位数据），骨架即真实布局。
    expect(find.byType(CollectionMemberCard), findsWidgets);
    expect(find.byType(CircularProgressIndicator), findsNothing);

    pendingCollection.complete(
      ResponseBody.fromString(
        '{"id":1,"name":"我的合集","description":"","item_count":0,"cover_image":null}',
        200,
        headers: const <String, List<String>>{
          Headers.contentTypeHeader: <String>[Headers.jsonContentType],
        },
      ),
    );
    await tester.pumpAndSettle();
  });

  testWidgets('桌面详情渲染标题块 / 播放全部 / 成员总数', (WidgetTester tester) async {
    enqueueInitialLoad();
    await pumpPage(tester);

    expect(find.byKey(const Key('video-collection-detail-page')), findsOneWidget);
    expect(find.text('我的合集'), findsOneWidget);
    expect(find.text('简介内容'), findsOneWidget);
    expect(
      find.byKey(const Key('video-collection-play-all-button')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('video-collection-total')), findsOneWidget);
    expect(find.text('3 个视频'), findsOneWidget);
    expect(
      find.byKey(const Key('video-collection-enter-selection-button')),
      findsOneWidget,
    );
    // 网格排布，卡片挂可测试的 menu key。
    expect(
      find.byKey(const Key('video-collection-grid-menu-1')),
      findsOneWidget,
    );
  });

  testWidgets('桌面详情多选态顶栏内联批量动作', (WidgetTester tester) async {
    enqueueInitialLoad();
    await pumpPage(tester);

    await tester.tap(
      find.byKey(const Key('video-collection-enter-selection-button')),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('video-collection-batch-add-collection-button')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('video-collection-batch-remove-button')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('video-collection-batch-delete-button')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('video-collection-exit-selection-button')),
      findsOneWidget,
    );
  });

  testWidgets('桌面网格悬停展示整行动作按钮', (WidgetTester tester) async {
    enqueueInitialLoad();
    await pumpPage(tester);

    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: Offset.zero);
    addTearDown(mouse.removePointer);
    await mouse.moveTo(tester.getCenter(find.byKey(const ValueKey<int>(1))));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('video-collection-grid-play-1')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('video-collection-grid-thumbnails-1')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('video-collection-grid-add-collection-1')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('video-collection-grid-remove-1')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('video-collection-grid-delete-1')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
}
