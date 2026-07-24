import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oktoast/oktoast.dart';
import 'package:provider/provider.dart';
import 'package:sakuramedia/core/session/session_store.dart';
import 'package:sakuramedia/features/movies/data/api/movies_api.dart';
import 'package:sakuramedia/features/movies/presentation/controllers/notifiers/movie_collection_type_change_notifier.dart';
import 'package:sakuramedia/features/movies/presentation/controllers/notifiers/movie_subscription_change_notifier.dart';
import 'package:sakuramedia/features/movies/presentation/pages/desktop/series_movies_page.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/interaction/selection/app_selection_toolbar.dart';
import 'package:sakuramedia/widgets/base/navigation/app_filter_entry_button.dart';
import 'package:sakuramedia/widgets/base/navigation/app_list_header.dart';

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
              'series_name': '某个系列',
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
    tester.view.physicalSize = const Size(1280, 1000);
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
            home: const Scaffold(
              body: DesktopSeriesMoviesPage(seriesId: 7, seriesName: '某个系列'),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('顶栏用 AppListHeader，无筛选维度所以不渲染筛选入口', (
    WidgetTester tester,
  ) async {
    enqueueSeriesMovies();
    await pumpPage(tester);

    expect(find.byType(AppListHeader), findsOneWidget);
    // 后端 /movies/by-series 只吃 seriesId + 分页，本页没有筛选可放。
    expect(find.byType(AppFilterEntryButton), findsNothing);

    // 系列名与总数是只读信息。
    expect(
      find.descendant(
        of: find.byKey(const Key('app-list-header-information-slots')),
        matching: find.byKey(const Key('series-movies-title')),
      ),
      findsOneWidget,
    );
    expect(find.text('某个系列'), findsOneWidget);
    expect(find.text('共 2 部'), findsOneWidget);
  });

  testWidgets('「同步系列影片」与「选择」都在操作槽里，不再另起一行', (
    WidgetTester tester,
  ) async {
    enqueueSeriesMovies();
    await pumpPage(tester);

    final actionSlots = find.byKey(const Key('app-list-header-action-slots'));
    expect(
      find.descendant(
        of: actionSlots,
        matching: find.byKey(const Key('series-movies-import-button')),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: actionSlots,
        matching: find.byKey(
          const Key('series-movies-enter-selection-button'),
        ),
      ),
      findsOneWidget,
    );
  });

  testWidgets('进入多选原地改写整条顶栏，高度不变', (WidgetTester tester) async {
    enqueueSeriesMovies();
    await pumpPage(tester);

    final headerHeight = tester.getSize(find.byType(AppListHeader)).height;

    await tester.tap(
      find.byKey(const Key('series-movies-enter-selection-button')),
    );
    await tester.pumpAndSettle();

    expect(find.byType(AppListHeader), findsNothing);
    expect(find.byType(AppSelectionHeaderToolbar), findsOneWidget);
    expect(
      tester.getSize(find.byType(AppSelectionHeaderToolbar)).height,
      headerHeight,
    );
  });
}
