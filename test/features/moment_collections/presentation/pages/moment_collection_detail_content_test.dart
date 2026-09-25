import 'package:flutter/gestures.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' show ProviderScope;
import 'package:sakuramedia/app/app_platform.dart';
import 'package:sakuramedia/core/network/providers/api_client_provider.dart';
import 'package:sakuramedia/core/session/providers/session_store_provider.dart';
import 'package:sakuramedia/features/media/data/media_api.dart';
import 'package:sakuramedia/features/media/presentation/providers/media_api_provider.dart';
import 'package:sakuramedia/features/moment_collections/data/api/moment_collections_api.dart';
import 'package:sakuramedia/features/moment_collections/presentation/pages/shared/moment_collection_detail_content.dart';
import 'package:sakuramedia/features/moment_collections/presentation/providers/moment_collections_api_provider.dart';
import 'package:sakuramedia/features/movies/data/api/movies_api.dart';
import 'package:sakuramedia/features/movies/presentation/providers/movies_api_provider.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oktoast/oktoast.dart';
import 'package:sakuramedia/core/network/api_client.dart';
import 'package:sakuramedia/core/session/session_store.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/shell/mobile/app_mobile_subpage_shell.dart';

import '../../../../support/fake_http_client_adapter.dart';

Map<String, dynamic> _collectionJson({
  String name = '周末回看',
  int pointCount = 2,
}) => <String, dynamic>{
  'id': 7,
  'name': name,
  'description': '按时间整理的时刻',
  'point_count': pointCount,
  'cover_image': null,
  'created_at': '2026-09-10T10:00:00Z',
  'updated_at': '2026-09-10T11:00:00Z',
};

Map<String, dynamic> _pointJson(
  int pointId,
  int position, {
  bool withImage = false,
  int? mediaId,
}) => <String, dynamic>{
  'point_id': pointId,
  'media_id': mediaId ?? 100 + pointId,
  'movie_number': 'ABC-0$pointId',
  'video_item_id': null,
  'thumbnail_id': 200 + pointId,
  'offset_seconds': pointId * 10,
  'image': withImage
      ? <String, dynamic>{
          'id': pointId,
          'origin': '/thumb-$pointId.webp',
          'small': '/thumb-$pointId.webp',
          'medium': '/thumb-$pointId.webp',
          'large': '/thumb-$pointId.webp',
        }
      : null,
  'position': position,
};

void _enqueueMovieDetail(FakeHttpClientAdapter adapter, String movieNumber) {
  adapter.enqueueJson(
    method: 'GET',
    path: '/movies/$movieNumber',
    body: <String, dynamic>{
      'movie_number': movieNumber,
      'title': 'Movie 1',
      'can_play': true,
    },
  );
}

Map<String, dynamic> _mediaPointJson(int pointId) => <String, dynamic>{
  'point_id': pointId,
  'media_id': 100 + pointId,
  'movie_number': 'ABC-0$pointId',
  'video_item_id': null,
  'thumbnail_id': 200 + pointId,
  'offset_seconds': pointId * 10,
  'image': null,
  'created_at': '2026-09-10T10:00:00Z',
};

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
    adapter.setFallbackJson(
      method: 'GET',
      path: '/status/capabilities',
      body: const <String, dynamic>{
        'movie_similarity': true,
        'image_search': true,
      },
    );
    apiClient.rawDio.httpClientAdapter = adapter;
    apiClient.rawRefreshDio.httpClientAdapter = adapter;
  });

  tearDown(() {
    apiClient.dispose();
  });

  void enqueueInitialLoad({int total = 2, bool withImage = false}) {
    adapter.enqueueJson(
      method: 'GET',
      path: '/moment-collections/7',
      body: _collectionJson(pointCount: total),
    );
    adapter.enqueueJson(
      method: 'GET',
      path: '/moment-collections/7/points',
      body: <String, dynamic>{
        'items': <Map<String, dynamic>>[
          for (var i = 0; i < total; i++)
            _pointJson(10 + i, i, withImage: withImage),
        ],
        'page': 1,
        'page_size': 50,
        'total': total,
      },
    );
  }

  Widget buildApp(Widget home) {
    return ProviderScope(
      overrides: [
        apiClientProvider.overrideWithValue(apiClient),
        sessionStoreProvider.overrideWithValue(sessionStore),
        momentCollectionsApiProvider.overrideWithValue(
          MomentCollectionsApi(apiClient: apiClient),
        ),
        mediaApiProvider.overrideWithValue(MediaApi(apiClient: apiClient)),
        moviesApiProvider.overrideWithValue(MoviesApi(apiClient: apiClient)),
      ],
      child: OKToast(
        child: MaterialApp(theme: sakuraThemeData, home: home),
      ),
    );
  }

  Future<void> pumpDesktop(WidgetTester tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1280, 900);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      buildApp(
        const Scaffold(
          body: MomentCollectionDetailContent(collectionId: 7, isMobile: false),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> pumpMobile(WidgetTester tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      buildApp(
        const AppPlatformScope(
          platform: AppPlatform.mobile,
          child: AppMobileSubpageShell(
            title: '合集',
            defaultLocation: '/mobile/library/moment-collections',
            child: MomentCollectionDetailContent(
              collectionId: 7,
              isMobile: true,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> hoverGridCard(WidgetTester tester, int pointId) async {
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: Offset.zero);
    addTearDown(mouse.removePointer);
    await mouse.moveTo(tester.getCenter(find.byKey(ValueKey<int>(pointId))));
    await tester.pumpAndSettle();
  }

  testWidgets('桌面固定网格且不再提供列表切换', (WidgetTester tester) async {
    enqueueInitialLoad();
    await pumpDesktop(tester);

    expect(
      find.byKey(const Key('moment-collection-detail-grid')),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const Key('app-list-header-information-slots')),
        matching: find.byKey(const Key('moment-collection-total')),
      ),
      findsOneWidget,
    );
    expect(find.text('2 个时刻'), findsOneWidget);
    expect(
      find.byKey(const Key('moment-collection-detail-list')),
      findsNothing,
    );
    expect(
      find.byKey(const Key('moment-collection-layout-toggle')),
      findsNothing,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('桌面网格收起态不铺文字，悬停渐显信息与动作行', (WidgetTester tester) async {
    enqueueInitialLoad(total: 1);
    await pumpDesktop(tester);

    expect(find.text('ABC-010'), findsNothing);
    expect(find.byKey(const Key('moment-collection-grid-play-10')), findsNothing);

    await hoverGridCard(tester, 10);

    expect(find.textContaining('ABC-010', findRichText: true), findsOneWidget);
    expect(
      find.textContaining('JAV · 01:40', findRichText: true),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('moment-collection-grid-play-10')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('moment-collection-grid-movie-10')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('moment-collection-grid-remove-10')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('moment-collection-grid-delete-10')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('桌面网格来源已删除的时刻不显示悬停播放键', (
    WidgetTester tester,
  ) async {
    adapter.enqueueJson(
      method: 'GET',
      path: '/moment-collections/7',
      body: _collectionJson(pointCount: 1),
    );
    adapter.enqueueJson(
      method: 'GET',
      path: '/moment-collections/7/points',
      body: <String, dynamic>{
        'items': <Map<String, dynamic>>[_pointJson(10, 0, mediaId: 0)],
        'page': 1,
        'page_size': 50,
        'total': 1,
      },
    );
    await pumpDesktop(tester);
    await hoverGridCard(tester, 10);

    expect(
      find.textContaining('来源已删除', findRichText: true),
      findsOneWidget,
    );
    expect(find.byKey(const Key('moment-collection-grid-play-10')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('移动端网格保持标题常显且没有悬停播放键', (WidgetTester tester) async {
    enqueueInitialLoad(total: 1);
    await pumpMobile(tester);

    expect(find.text('ABC-010'), findsOneWidget);
    expect(
      find.byKey(const Key('mobile-moment-collection-grid-play-10')),
      findsNothing,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('桌面多选后批量从合集移除', (WidgetTester tester) async {
    enqueueInitialLoad();
    await pumpDesktop(tester);

    await tester.tap(
      find.byKey(const Key('moment-collection-enter-selection-button')),
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('moment-collection-batch-remove-button')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey<int>(10)));
    await tester.pumpAndSettle();

    adapter.enqueueJson(
      method: 'DELETE',
      path: '/moment-collections/7/points/10',
      statusCode: 204,
    );
    adapter.enqueueJson(
      method: 'GET',
      path: '/moment-collections/7',
      body: _collectionJson(pointCount: 1),
    );
    adapter.enqueueJson(
      method: 'GET',
      path: '/moment-collections/7/points',
      body: <String, dynamic>{
        'items': <Map<String, dynamic>>[_pointJson(11, 0)],
        'page': 1,
        'page_size': 50,
        'total': 1,
      },
    );

    await tester.tap(
      find.byKey(const Key('moment-collection-batch-remove-button')),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const Key('moment-collection-batch-remove-confirm-button')),
    );
    await tester.pumpAndSettle();

    expect(adapter.hitCount('DELETE', '/moment-collections/7/points/10'), 1);
    expect(find.byKey(const ValueKey<int>(10)), findsNothing);
    expect(tester.takeException(), isNull);
    // 让批量完成的 toast 计时器结束，避免测试结束时仍有 pending timer。
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('移动端长按进入多选', (WidgetTester tester) async {
    enqueueInitialLoad();
    await pumpMobile(tester);

    await tester.longPress(find.byKey(const ValueKey<int>(10)));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('mobile-moment-collection-batch-bottom-bar')),
      findsOneWidget,
    );
    expect(find.text('已选 1 个'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('移动端合集名报到返回栏', (WidgetTester tester) async {
    enqueueInitialLoad();
    await pumpMobile(tester);

    expect(
      tester.widget<Text>(find.byKey(const Key('mobile-subpage-title'))).data,
      '周末回看',
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('桌面合集详情点开时刻预览与时刻列表同款（含加入合集）', (WidgetTester tester) async {
    enqueueInitialLoad(total: 1, withImage: true);
    _enqueueMovieDetail(adapter, 'ABC-010');
    await pumpDesktop(tester);

    await tester.tap(find.byKey(const ValueKey<int>(10)));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('image-search-result-preview-dialog')),
      findsOneWidget,
    );
    expect(find.text('相似图片'), findsOneWidget);
    expect(find.text('保存'), findsOneWidget);
    expect(find.text('删除标记'), findsOneWidget);
    expect(find.text('加入合集'), findsOneWidget);
    // 内联导航与时刻列表一致：不再显示独立「播放 / 影片详情」按钮。
    expect(find.text('播放'), findsNothing);
    expect(find.text('影片详情'), findsNothing);
    expect(
      find.byKey(const Key('image-search-result-preview-movie-info-section')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('桌面合集详情预览点加入合集打开合集选择弹层', (WidgetTester tester) async {
    enqueueInitialLoad(total: 1, withImage: true);
    _enqueueMovieDetail(adapter, 'ABC-010');
    await pumpDesktop(tester);

    await tester.tap(find.byKey(const ValueKey<int>(10)));
    await tester.pumpAndSettle();

    adapter.enqueueJson(
      method: 'GET',
      path: '/moment-collections',
      body: <Map<String, dynamic>>[_collectionJson()],
    );
    adapter.enqueueJson(
      method: 'GET',
      path: '/media-points/10/collections',
      body: const <Map<String, dynamic>>[],
    );

    await tester.tap(find.text('加入合集'));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('add-to-moment-collection-list')),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const Key('add-to-moment-collection-list')),
        matching: find.text('周末回看'),
      ),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('移动合集详情点开时刻预览为底部抽屉且含加入合集', (WidgetTester tester) async {
    enqueueInitialLoad(total: 1, withImage: true);
    _enqueueMovieDetail(adapter, 'ABC-010');
    await pumpMobile(tester);

    await tester.tap(find.byKey(const ValueKey<int>(10)));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('mobile-moment-collection-preview-bottom-sheet')),
      findsOneWidget,
    );
    expect(find.text('加入合集'), findsOneWidget);
    expect(find.text('播放'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('「添加时刻」入口打开选择器并可即时加入', (WidgetTester tester) async {
    // 选择器自身的防抖 / 出池 / 空态 / 分页行为见
    // test/features/moment_collections/presentation/widgets/add_moments_picker_test.dart，
    // 这里只验证详情页入口与加成员链路。
    enqueueInitialLoad(total: 1);
    await pumpDesktop(tester);

    adapter.enqueueJson(
      method: 'GET',
      path: '/media-points',
      body: <String, dynamic>{
        'items': <Map<String, dynamic>>[_mediaPointJson(12)],
        'page': 1,
        'page_size': 24,
        'total': 1,
      },
    );
    await tester.tap(
      find.byKey(const Key('moment-collection-add-moments-button')),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('add-moments-to-collection-dialog')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('add-moments-option-12')), findsOneWidget);

    adapter.enqueueJson(
      method: 'PUT',
      path: '/moment-collections/7/points/12',
      statusCode: 204,
    );
    await tester.tap(find.byKey(const Key('add-moments-option-12')));
    await tester.pumpAndSettle();
    expect(adapter.hitCount('PUT', '/moment-collections/7/points/12'), 1);
    // 让「已加入」toast 计时器结束，避免测试结束时仍有 pending timer。
    await tester.pump(const Duration(seconds: 3));
    expect(tester.takeException(), isNull);
  });
}
