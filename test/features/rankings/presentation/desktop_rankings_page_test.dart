import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oktoast/oktoast.dart';
import 'package:provider/provider.dart';
import 'package:sakuramedia/core/session/session_store.dart';
import 'package:sakuramedia/features/movies/data/api/movies_api.dart';
import 'package:sakuramedia/features/movies/presentation/controllers/notifiers/movie_subscription_change_notifier.dart';
import 'package:sakuramedia/features/rankings/data/rankings_api.dart';
import 'package:sakuramedia/features/rankings/presentation/desktop_rankings_page.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/layout/scrolling/app_filter_total_header.dart';
import 'package:sakuramedia/widgets/base/navigation/app_filter_entry_button.dart';
import 'package:sakuramedia/widgets/base/navigation/app_list_header.dart';

import '../../../support/test_api_bundle.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SessionStore sessionStore;
  late TestApiBundle bundle;

  setUp(() async {
    sessionStore = SessionStore.inMemory();
    await sessionStore.saveBaseUrl('https://api.example.com');
    await sessionStore.saveTokens(
      accessToken: 'access-token',
      refreshToken: 'refresh-token',
      expiresAt: DateTime.parse('2026-03-10T12:00:00Z'),
    );
    bundle = await createTestApiBundle(sessionStore);
  });

  tearDown(() {
    bundle.dispose();
  });

  void enqueueFilterMetadata(TestApiBundle bundle) {
    bundle.adapter.enqueueJson(
      method: 'GET',
      path: '/ranking-sources',
      body: <Map<String, dynamic>>[
        <String, dynamic>{'source_key': 'javdb', 'name': 'JavDB'},
      ],
    );
    bundle.adapter.enqueueJson(
      method: 'GET',
      path: '/ranking-sources/javdb/boards',
      body: <Map<String, dynamic>>[
        <String, dynamic>{
          'source_key': 'javdb',
          'board_key': 'censored',
          'name': '有码',
          'supported_periods': <String>['daily', 'weekly'],
          'default_period': 'daily',
        },
      ],
    );
  }

  testWidgets('桌面榜单顶栏与移动端同构：榜单名筛选入口 + 总数 / 更新时间信息槽', (
    WidgetTester tester,
  ) async {
    enqueueFilterMetadata(bundle);
    bundle.adapter.enqueueJson(
      method: 'GET',
      path: '/ranking-sources/javdb/boards/censored/items',
      body: _rankingItemsJson(total: 2, syncedAt: '2026-05-08T09:00:00'),
    );

    await _pumpRankingsPage(tester, sessionStore: sessionStore, bundle: bundle);
    await tester.pumpAndSettle();

    // 顶栏收敛到 AppListHeader，旧的 AppFilterTotalHeader 不再出现。
    expect(find.byType(AppListHeader), findsOneWidget);
    expect(find.byType(AppFilterTotalHeader), findsNothing);

    // 筛选入口与移动端共用同一个按钮，摘要只报「榜单」这一主维度。
    final entry = tester.widget<AppFilterEntryButton>(
      find.byType(AppFilterEntryButton),
    );
    expect(entry.label, '有码');
    expect(entry.icon, Icons.leaderboard_outlined);

    // 总数与抓取时间是两个独立的只读信息胶囊，不再拼成一段文本。
    expect(find.byKey(const Key('desktop-rankings-page-total')), findsOneWidget);
    expect(find.text('2 部'), findsOneWidget);
    expect(find.byKey(const Key('desktop-rankings-synced-at')), findsOneWidget);
    expect(find.text('05/08 09:00'), findsOneWidget);

    // 「选择」留在右侧操作槽。
    expect(
      find.descendant(
        of: find.byKey(const Key('app-list-header-action-slots')),
        matching: find.text('选择'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('桌面筛选浮层与移动抽屉同构，点选周期即时生效', (WidgetTester tester) async {
    enqueueFilterMetadata(bundle);
    bundle.adapter.enqueueJson(
      method: 'GET',
      path: '/ranking-sources/javdb/boards/censored/items',
      body: _rankingItemsJson(total: 2),
    );

    await _pumpRankingsPage(tester, sessionStore: sessionStore, bundle: bundle);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('desktop-rankings-filter-trigger')));
    await tester.pumpAndSettle();

    // 面板内容与移动抽屉逐节一致（来源 / 榜单 / 周期 / 排序）。
    expect(find.byKey(const Key('rankings-filter-panel')), findsOneWidget);
    expect(find.text('JavDB'), findsWidgets);
    expect(find.text('有码'), findsWidgets);

    bundle.adapter.enqueueJson(
      method: 'GET',
      path: '/ranking-sources/javdb/boards/censored/items',
      body: _rankingItemsJson(total: 1),
    );

    await tester.tap(find.byKey(const Key('rankings-filter-period-weekly')));
    await tester.pumpAndSettle();

    // 即时生效：点选当场触发带新周期的重新拉取，面板保持打开。
    final lastRequest = bundle.adapter.requests.last;
    expect(lastRequest.path, '/ranking-sources/javdb/boards/censored/items');
    expect(lastRequest.uri.queryParameters['period'], 'weekly');
    expect(find.byKey(const Key('rankings-filter-panel')), findsOneWidget);
    expect(find.text('1 部'), findsOneWidget);
  });

  testWidgets('筛选元数据加载完成前筛选入口不响应点击', (WidgetTester tester) async {
    enqueueFilterMetadata(bundle);
    bundle.adapter.enqueueJson(
      method: 'GET',
      path: '/ranking-sources/javdb/boards/censored/items',
      body: _rankingItemsJson(total: 2),
    );

    await _pumpRankingsPage(tester, sessionStore: sessionStore, bundle: bundle);
    // 只 pump 一帧：来源 / 榜单都还在飞，page state 仍是 isFilterLoading。
    await tester.pump();

    await tester.tap(find.byKey(const Key('desktop-rankings-filter-trigger')));
    await tester.pump();

    expect(find.byKey(const Key('rankings-filter-panel')), findsNothing);

    // 元数据到齐后同一个入口恢复可用。
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('desktop-rankings-filter-trigger')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('rankings-filter-panel')), findsOneWidget);
  });
}

Future<void> _pumpRankingsPage(
  WidgetTester tester, {
  required SessionStore sessionStore,
  required TestApiBundle bundle,
}) {
  return tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<SessionStore>.value(value: sessionStore),
        Provider<RankingsApi>.value(value: bundle.rankingsApi),
        Provider<MoviesApi>.value(value: bundle.moviesApi),
        ChangeNotifierProvider<MovieSubscriptionChangeNotifier>(
          create: (_) => MovieSubscriptionChangeNotifier(),
        ),
      ],
      child: OKToast(
        child: MaterialApp(
          theme: sakuraThemeData,
          home: const Scaffold(body: DesktopRankingsPage()),
        ),
      ),
    ),
  );
}

Map<String, dynamic> _rankingItemsJson({
  int page = 1,
  int pageSize = 24,
  int total = 1,
  String? syncedAt,
  List<Map<String, dynamic>>? items,
}) {
  return <String, dynamic>{
    'items': items ?? <Map<String, dynamic>>[_rankedItem()],
    'page': page,
    'page_size': pageSize,
    'total': total,
    if (syncedAt != null) 'synced_at': syncedAt,
  };
}

Map<String, dynamic> _rankedItem({
  int rank = 1,
  String movieNumber = 'ABP-001',
}) {
  return <String, dynamic>{
    'rank': rank,
    'javdb_id': 'javdb-$movieNumber',
    'movie_number': movieNumber,
    'title': 'Movie $movieNumber',
    'cover_image': null,
    'thin_cover_image': null,
    'release_date': null,
    'duration_minutes': 0,
    'heat': 0,
    'is_subscribed': false,
    'can_play': false,
  };
}
