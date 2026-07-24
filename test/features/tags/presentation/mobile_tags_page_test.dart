import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oktoast/oktoast.dart';
import 'package:provider/provider.dart';
import 'package:sakuramedia/core/session/session_store.dart';
import 'package:sakuramedia/features/movies/data/api/movies_api.dart';
import 'package:sakuramedia/features/movies/presentation/controllers/notifiers/movie_collection_type_change_notifier.dart';
import 'package:sakuramedia/features/movies/presentation/controllers/notifiers/movie_subscription_change_notifier.dart';
import 'package:sakuramedia/features/tags/data/tags_api.dart';
import 'package:sakuramedia/features/tags/presentation/mobile_tags_page.dart';
import 'package:sakuramedia/theme.dart';

import '../../../support/test_api_bundle.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SessionStore sessionStore;
  late TestApiBundle bundle;
  late TagsApi tagsApi;

  setUp(() async {
    sessionStore = SessionStore.inMemory();
    await sessionStore.saveBaseUrl('https://api.example.com');
    await sessionStore.saveTokens(
      accessToken: 'access-token',
      refreshToken: 'refresh-token',
      expiresAt: DateTime.parse('2026-03-10T12:00:00Z'),
    );
    bundle = await createTestApiBundle(sessionStore);
    tagsApi = TagsApi(apiClient: bundle.apiClient);
  });

  tearDown(() {
    bundle.dispose();
  });

  Map<String, dynamic> moviesPage() => <String, dynamic>{
        'items': <Map<String, dynamic>>[
          <String, dynamic>{
            'javdb_id': 'MovieA1',
            'movie_number': 'ABC-001',
            'title': 'Movie 1',
            'cover_image': null,
            'release_date': '2024-01-02',
            'duration_minutes': 120,
            'is_subscribed': false,
            'can_play': true,
          },
        ],
        'page': 1,
        'page_size': 24,
        'total': 1,
      };

  List<String?> movieTagMatches() => bundle.adapter.requests
      .where((request) => request.uri.path == '/movies')
      .map((request) => request.uri.queryParameters['tag_match'])
      .toList(growable: false);

  Widget wrap(Widget child) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<SessionStore>.value(value: sessionStore),
        Provider<MoviesApi>.value(value: bundle.moviesApi),
        Provider<TagsApi>.value(value: tagsApi),
        ChangeNotifierProvider(
          create: (_) => MovieSubscriptionChangeNotifier(),
        ),
        ChangeNotifierProvider(
          create: (_) => MovieCollectionTypeChangeNotifier(),
        ),
      ],
      child: OKToast(
        child: MaterialApp(
          theme: sakuraThemeData,
          home: Scaffold(body: child),
        ),
      ),
    );
  }

  testWidgets(
    'caps popular tags to popularLimit and hides 展开全部',
    (WidgetTester tester) async {
      bundle.adapter.enqueueJson(
        method: 'GET',
        path: '/tags',
        body: <Map<String, dynamic>>[
          for (var i = 0; i < 30; i++)
            <String, dynamic>{
              'tag_id': i,
              'name': 'tag$i',
              'movie_count': 100 - i,
            },
        ],
      );

      await tester.pumpWidget(wrap(const MobileTagsPage()));
      await tester.pumpAndSettle();

      // popularLimit=5：移动端仅展示前 5 个热门标签，更多标签靠搜索，不出现「展开全部」。
      expect(find.byKey(const Key('tags-option-4')), findsOneWidget);
      expect(find.byKey(const Key('tags-option-5')), findsNothing);
      expect(find.text('展开全部'), findsNothing);
    },
  );

  testWidgets(
    'shows all popular tags when fewer than popularLimit',
    (WidgetTester tester) async {
      bundle.adapter.enqueueJson(
        method: 'GET',
        path: '/tags',
        body: <Map<String, dynamic>>[
          for (var i = 0; i < 3; i++)
            <String, dynamic>{
              'tag_id': i,
              'name': 'tag$i',
              'movie_count': 100 - i,
            },
        ],
      );

      await tester.pumpWidget(wrap(const MobileTagsPage()));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('tags-option-2')), findsOneWidget);
      expect(find.text('展开全部'), findsNothing);
    },
  );

  testWidgets(
    'preselected tag fetches movies with tag_match=or then and on toggle',
    (WidgetTester tester) async {
      bundle.adapter
        ..enqueueJson(
          method: 'GET',
          path: '/tags',
          body: <Map<String, dynamic>>[
            <String, dynamic>{'tag_id': 1, 'name': '巨乳', 'movie_count': 100},
            <String, dynamic>{'tag_id': 2, 'name': '单体作品', 'movie_count': 80},
          ],
        )
        ..enqueueJson(method: 'GET', path: '/movies', body: moviesPage())
        ..enqueueJson(method: 'GET', path: '/movies', body: moviesPage());

      await tester.pumpWidget(wrap(const MobileTagsPage(initialTagId: 1)));
      await tester.pumpAndSettle();

      // 预选标签首拉影片默认走 or。
      expect(movieTagMatches(), <String?>['or']);

      await tester.tap(find.byKey(const Key('tags-match-and')));
      await tester.pumpAndSettle();

      // 切到「全部」后追加一次 and 请求。
      expect(movieTagMatches(), <String?>['or', 'and']);
    },
  );

  testWidgets('影片筛选走底部抽屉，而不是桌面就地浮层', (WidgetTester tester) async {
    bundle.adapter
      ..enqueueJson(
        method: 'GET',
        path: '/tags',
        body: <Map<String, dynamic>>[
          <String, dynamic>{'tag_id': 1, 'name': '巨乳', 'movie_count': 100},
        ],
      )
      ..enqueueJson(method: 'GET', path: '/movies', body: moviesPage());

    await tester.pumpWidget(wrap(const MobileTagsPage(initialTagId: 1)));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('mobile-tags-filter-button')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('mobile-movies-filter-drawer')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('movies-filter-panel')), findsNothing);
  });

  testWidgets('多选走移动布局：顶栏只留计数/全选，批量动作在底部条且不溢出', (
    WidgetTester tester,
  ) async {
    // 移动壳 body 左右各留 AppPageInsets.compact(8)，390 屏的可用宽是 374。
    // 桌面式一行 toolbar 在这个宽度下会 RenderFlex 溢出，故必须走移动布局。
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(374, 844);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    bundle.adapter
      ..enqueueJson(
        method: 'GET',
        path: '/tags',
        body: <Map<String, dynamic>>[
          <String, dynamic>{'tag_id': 1, 'name': '巨乳', 'movie_count': 100},
        ],
      )
      ..enqueueJson(method: 'GET', path: '/movies', body: moviesPage());

    await tester.pumpWidget(wrap(const MobileTagsPage(initialTagId: 1)));
    await tester.pumpAndSettle();

    // 移动端多选入口挂在卡片长按上，顶栏不常驻「选择」。
    expect(
      find.byKey(const Key('movie-list-enter-selection-button')),
      findsNothing,
    );

    await tester.longPress(
      find.byKey(const Key('movie-summary-card-ABC-001')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('选择'));
    await tester.pumpAndSettle();

    // 顶栏原地改写为计数 + 全选；批量动作在贴底的操作条里。
    expect(
      find.byKey(const Key('app-list-header-selection-label')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('movie-list-batch-bottom-bar')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
}
