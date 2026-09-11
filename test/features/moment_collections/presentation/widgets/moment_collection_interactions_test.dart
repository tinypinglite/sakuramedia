import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oktoast/oktoast.dart';
import 'package:sakuramedia/core/network/api_client.dart';
import 'package:sakuramedia/core/session/session_store.dart';
import 'package:sakuramedia/core/session/providers/session_store_provider.dart';
import 'package:sakuramedia/features/moment_collections/data/api/moment_collections_api.dart';
import 'package:sakuramedia/features/moment_collections/presentation/pages/shared/moment_collection_detail_content.dart';
import 'package:sakuramedia/features/moment_collections/presentation/pages/shared/moment_collections_content.dart';
import 'package:sakuramedia/features/moment_collections/presentation/providers/moment_collection_mutation_events_provider.dart';
import 'package:sakuramedia/features/moment_collections/presentation/providers/moment_collections_api_provider.dart';
import 'package:sakuramedia/features/moment_collections/presentation/widgets/add_to_moment_collection_dialog.dart';
import 'package:sakuramedia/features/media/data/media_api.dart';
import 'package:sakuramedia/features/media/presentation/providers/media_api_provider.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/overlays/app_desktop_dialog.dart';

import '../../../../support/fake_http_client_adapter.dart';

Map<String, dynamic> _collectionJson({
  int id = 7,
  String name = '周末回看',
  int pointCount = 3,
}) => <String, dynamic>{
  'id': id,
  'name': name,
  'description': '按时间整理的时刻',
  'point_count': pointCount,
  'cover_image': null,
  'created_at': '2026-09-10T10:00:00Z',
  'updated_at': '2026-09-10T11:00:00Z',
};

Map<String, dynamic> _pointJson() => <String, dynamic>{
  'point_id': 12,
  'media_id': 34,
  'movie_number': 'ABC-001',
  'video_item_id': null,
  'thumbnail_id': 56,
  'offset_seconds': 90,
  'image': null,
  'position': 0,
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ApiClient apiClient;
  late FakeHttpClientAdapter adapter;
  late MomentCollectionsApi api;
  late SessionStore sessionStore;

  setUp(() async {
    sessionStore = SessionStore.inMemory();
    await sessionStore.saveBaseUrl('https://api.example.com');
    await sessionStore.saveTokens(
      accessToken: 'access-token',
      refreshToken: 'refresh-token',
      expiresAt: DateTime.parse('2026-09-10T12:00:00Z'),
    );
    apiClient = ApiClient(sessionStore: sessionStore);
    adapter = FakeHttpClientAdapter();
    apiClient.rawDio.httpClientAdapter = adapter;
    apiClient.rawRefreshDio.httpClientAdapter = adapter;
    api = MomentCollectionsApi(apiClient: apiClient);
  });

  tearDown(() {
    apiClient.dispose();
    sessionStore.dispose();
  });

  Future<void> pumpPage(WidgetTester tester, Widget child) {
    return tester.pumpWidget(
      ProviderScope(
        overrides: [
          sessionStoreProvider.overrideWithValue(sessionStore),
          momentCollectionsApiProvider.overrideWithValue(api),
          mediaApiProvider.overrideWithValue(MediaApi(apiClient: apiClient)),
        ],
        retry: (_, _) => null,
        child: OKToast(
          child: MaterialApp(
            theme: sakuraThemeData,
            home: Scaffold(body: child),
          ),
        ),
      ),
    );
  }

  testWidgets('加入合集时在同一弹窗内新建并自动选中', (WidgetTester tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1100, 760);
    addTearDown(tester.view.reset);

    adapter.enqueueJson(
      method: 'GET',
      path: '/moment-collections',
      body: <Map<String, dynamic>>[_collectionJson()],
    );
    adapter.enqueueJson(
      method: 'GET',
      path: '/media-points/12/collections',
      body: const <Map<String, dynamic>>[],
    );

    await pumpPage(
      tester,
      Builder(
        builder: (context) => Center(
          child: ElevatedButton(
            onPressed: () => showAddToMomentCollectionDialog(
              context,
              pointId: 12,
              useBottomDrawer: false,
            ),
            child: const Text('打开'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('打开'));
    await tester.pumpAndSettle();

    expect(find.byType(AppDesktopDialog), findsOneWidget);
    await tester.tap(find.byTooltip('新建合集'));
    await tester.pumpAndSettle();

    expect(find.byType(AppDesktopDialog), findsOneWidget);
    expect(find.text('新建时刻合集'), findsOneWidget);
    expect(find.text('合集名称'), findsOneWidget);
    expect(find.text('描述（可选）'), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('moment-collection-name-field')),
      '旅行片段',
    );
    adapter.enqueueJson(
      method: 'POST',
      path: '/moment-collections',
      statusCode: 201,
      body: _collectionJson(id: 8, name: '旅行片段', pointCount: 0),
    );
    adapter.enqueueJson(
      method: 'PUT',
      path: '/moment-collections/8/points/12',
      statusCode: 204,
    );
    await tester.tap(find.byKey(const Key('moment-collection-submit-button')));
    await tester.pumpAndSettle();

    expect(find.byType(AppDesktopDialog), findsOneWidget);
    expect(find.text('加入合集'), findsOneWidget);
    expect(find.text('新建时刻合集'), findsNothing);
    final checkbox = tester.widget<Checkbox>(
      find.descendant(
        of: find.byKey(const Key('add-to-moment-collection-8')),
        matching: find.byType(Checkbox),
      ),
    );
    expect(checkbox.value, isTrue);
    expect(adapter.hitCount('PUT', '/moment-collections/8/points/12'), 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('未标记结果选择合集时才创建时刻并加入', (WidgetTester tester) async {
    adapter.enqueueJson(
      method: 'GET',
      path: '/moment-collections',
      body: <Map<String, dynamic>>[_collectionJson()],
    );
    adapter.enqueueJson(
      method: 'POST',
      path: '/media/34/points',
      statusCode: 201,
      body: _pointJson(),
    );
    adapter.enqueueJson(
      method: 'PUT',
      path: '/moment-collections/7/points/12',
      statusCode: 204,
    );

    await pumpPage(
      tester,
      Builder(
        builder: (context) => Center(
          child: ElevatedButton(
            onPressed: () => showAddToMomentCollectionDialog(
              context,
              mediaId: 34,
              thumbnailId: 56,
              useBottomDrawer: false,
            ),
            child: const Text('打开'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('打开'));
    await tester.pumpAndSettle();

    await tester.tap(
      find.descendant(
        of: find.byKey(const Key('add-to-moment-collection-7')),
        matching: find.byType(Checkbox),
      ),
    );
    await tester.pumpAndSettle();

    expect(adapter.hitCount('POST', '/media/34/points'), 1);
    expect(adapter.hitCount('PUT', '/moment-collections/7/points/12'), 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('合集列表错误后可重试并恢复内容', (WidgetTester tester) async {
    adapter.enqueueJson(
      method: 'GET',
      path: '/moment-collections',
      statusCode: 500,
      body: const <String, dynamic>{'detail': 'temporary failure'},
    );
    adapter.enqueueJson(
      method: 'GET',
      path: '/moment-collections',
      body: <Map<String, dynamic>>[_collectionJson()],
    );

    await pumpPage(
      tester,
      const MomentCollectionsContent(isMobile: false, onOpenDetail: _ignore),
    );
    await tester.pumpAndSettle();

    final retry = find.byKey(const Key('moment-collections-retry-button'));
    expect(retry, findsOneWidget);
    await tester.tap(retry);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('moment-collection-card-7')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('合集成员变更会刷新列表摘要', (WidgetTester tester) async {
    adapter.enqueueJson(
      method: 'GET',
      path: '/moment-collections',
      body: <Map<String, dynamic>>[_collectionJson(pointCount: 1)],
    );
    adapter.enqueueJson(
      method: 'GET',
      path: '/moment-collections',
      body: <Map<String, dynamic>>[_collectionJson(pointCount: 2)],
    );

    await pumpPage(
      tester,
      Consumer(
        builder: (context, ref, _) => Column(
          children: [
            const Expanded(
              child: MomentCollectionsContent(
                isMobile: false,
                onOpenDetail: _ignore,
              ),
            ),
            ElevatedButton(
              onPressed: () => ref
                  .read(momentCollectionMutationEventsProvider.notifier)
                  .reportChanged(7),
              child: const Text('触发合集变更'),
            ),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('1'), findsOneWidget);
    await tester.tap(find.text('触发合集变更'));
    await tester.pumpAndSettle();

    expect(find.text('2'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('合集详情错误后可重试，并提示拖动把手排序', (WidgetTester tester) async {
    adapter.enqueueJson(
      method: 'GET',
      path: '/moment-collections/7',
      statusCode: 500,
      body: const <String, dynamic>{'detail': 'temporary failure'},
    );
    adapter.enqueueJson(
      method: 'GET',
      path: '/moment-collections/7/points',
      body: <String, dynamic>{
        'items': <Map<String, dynamic>>[_pointJson()],
        'page': 1,
        'page_size': 50,
        'total': 1,
      },
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
        'items': <Map<String, dynamic>>[_pointJson()],
        'page': 1,
        'page_size': 50,
        'total': 1,
      },
    );

    await pumpPage(
      tester,
      const MomentCollectionDetailContent(collectionId: 7, isMobile: false),
    );
    await tester.pumpAndSettle();

    final retry = find.byKey(
      const Key('moment-collection-detail-retry-button'),
    );
    expect(retry, findsOneWidget);
    await tester.tap(retry);
    await tester.pumpAndSettle();

    expect(find.text('1 个时刻 · 拖动右侧把手调整顺序'), findsOneWidget);
    expect(find.textContaining('长按拖动'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}

void _ignore(int _) {}
