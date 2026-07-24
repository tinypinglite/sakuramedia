import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oktoast/oktoast.dart';
import 'package:provider/provider.dart';
import 'package:sakuramedia/core/session/session_store.dart';
import 'package:sakuramedia/features/movies/data/api/movies_api.dart';
import 'package:sakuramedia/features/movies/presentation/controllers/notifiers/movie_collection_type_change_notifier.dart';
import 'package:sakuramedia/features/movies/presentation/controllers/notifiers/movie_subscription_change_notifier.dart';
import 'package:sakuramedia/features/movies/presentation/pages/mobile/series_movies_page.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/navigation/app_list_header.dart';
import 'package:sakuramedia/widgets/shell/mobile/app_mobile_subpage_shell.dart';

import '../../../../../support/test_api_bundle.dart';

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

  void enqueueSeriesMovies({int total = 2}) {
    bundle.adapter.enqueueJson(
      method: 'POST',
      path: '/movies/by-series',
      body: <String, dynamic>{
        'items': <Map<String, dynamic>>[
          for (var index = 0; index < total; index++)
            <String, dynamic>{
              'javdb_id': 'MovieA$index',
              'movie_number': 'ABC-00${index + 1}',
              'title': 'Movie $index',
              'series_name': '很长很长的系列名称需要放到返回栏里',
              'cover_image': null,
              'release_date': '2024-01-02',
              'duration_minutes': 120,
              'is_subscribed': false,
              'can_play': true,
            },
        ],
        'page': 1,
        'page_size': 24,
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
          Provider<MoviesApi>.value(value: bundle.moviesApi),
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
            // 真实路由把页面套在这个壳里（见 _MobileSubpageRouteData.buildPage）。
            home: const AppMobileSubpageShell(
              title: '系列影片',
              defaultLocation: '/mobile/library/movies',
              child: MobileSeriesMoviesPage(
                seriesId: 7,
                seriesName: '很长很长的系列名称需要放到返回栏里',
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('系列名报到返回栏，信息槽里只留总数', (WidgetTester tester) async {
    enqueueSeriesMovies();
    await pumpPage(tester);

    expect(
      tester.widget<Text>(find.byKey(const Key('mobile-subpage-title'))).data,
      '很长很长的系列名称需要放到返回栏里',
    );
    // 信息槽不再重复系列名，只剩总数。
    expect(find.byKey(const Key('series-movies-title')), findsNothing);
    expect(find.text('共 2 部'), findsOneWidget);
  });

  testWidgets('顶栏不常驻「选择」，多选入口在卡片长按菜单里', (WidgetTester tester) async {
    enqueueSeriesMovies();
    await pumpPage(tester);

    expect(
      find.byKey(const Key('series-movies-enter-selection-button')),
      findsNothing,
    );
    // 「同步系列影片」仍留在操作槽。
    expect(
      find.byKey(const Key('series-movies-import-button')),
      findsOneWidget,
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
      find.byKey(const Key('series-movies-batch-bottom-bar')),
      findsOneWidget,
    );
    expect(find.byType(AppListHeader), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
