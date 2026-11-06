import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/app/app_platform.dart';
import 'package:sakuramedia/core/session/session_store.dart';
import 'package:sakuramedia/features/movies/presentation/pages/shared/series_movies_content.dart';
import 'package:sakuramedia/l10n/app_localizations.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/interaction/refresh/app_page_refresh_scope.dart';
import 'package:sakuramedia/widgets/shell/mobile/app_mobile_subpage_shell.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../../support/fake_http_client_adapter.dart';
import '../../../../../support/logged_in_session_store.dart';
import '../../../../../support/test_api_bundle.dart';

const _seriesId = 9;
const _pageSize = 24;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SessionStore sessionStore;
  late TestApiBundle bundle;

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    sessionStore = await buildLoggedInSessionStore();
    bundle = await createTestApiBundle(sessionStore);
  });

  tearDown(() {
    bundle.dispose();
    sessionStore.dispose();
  });

  testWidgets('desktop series list keeps its first-page request and keys', (
    tester,
  ) async {
    _enqueueSeriesPage(
      bundle,
      movies: <Map<String, dynamic>>[
        _movie('ABC-001', seriesName: 'Series Alpha'),
      ],
      total: 1,
    );

    await _pumpSeriesContent(
      tester,
      bundle: bundle,
      desktop: true,
      initialSeriesName: 'Series Alpha',
    );

    expect(find.byKey(const Key('desktop-series-movies-page')), findsOneWidget);
    expect(
      find.byKey(const Key('desktop-series-movies-total')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('series-movies-title')), findsOneWidget);
    expect(
      find.byKey(const Key('series-movies-import-button')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('movie-summary-card-ABC-001')), findsOneWidget);

    final firstRequest = _seriesRequests(bundle).single;
    expect(firstRequest.body, <String, dynamic>{
      'series_id': _seriesId,
      'page': 1,
      'page_size': _pageSize,
    });

    await tester.tap(
      find.byKey(const Key('series-movies-enter-selection-button')),
    );
    await _pumpFrames(tester);

    expect(
      find.byKey(const Key('series-movies-exit-selection-button')),
      findsOneWidget,
    );
    await tester.tap(
      find.byKey(const Key('movie-summary-card-checkbox-ABC-001')),
    );
    await _pumpFrames(tester);

    expect(
      find.byKey(const Key('series-movies-selection-count-text')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('desktop series list auto-loads the next page', (tester) async {
    _enqueueSeriesPage(
      bundle,
      movies: <Map<String, dynamic>>[
        _movie('ABC-001', seriesName: 'Series Alpha'),
      ],
      total: 2,
    );
    _enqueueSeriesPage(
      bundle,
      movies: <Map<String, dynamic>>[
        _movie('ABC-002', seriesName: 'Series Alpha'),
      ],
      total: 2,
      page: 2,
    );

    await _pumpSeriesContent(
      tester,
      bundle: bundle,
      desktop: true,
      initialSeriesName: 'Series Alpha',
    );

    expect(find.byKey(const Key('movie-summary-card-ABC-001')), findsOneWidget);
    expect(find.byKey(const Key('movie-summary-card-ABC-002')), findsOneWidget);
    expect(
      _seriesRequests(bundle).map((request) => request.body['page']),
      <int>[1, 2],
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('series refresh replaces the retained list', (tester) async {
    _enqueueSeriesPage(
      bundle,
      movies: <Map<String, dynamic>>[
        _movie('ABC-001', seriesName: 'Series Alpha'),
      ],
      total: 1,
    );
    _enqueueSeriesPage(
      bundle,
      movies: <Map<String, dynamic>>[
        _movie('ABC-002', seriesName: 'Series Alpha'),
      ],
      total: 1,
    );

    final refreshCallbacks = <Future<void> Function()>[];
    await _pumpSeriesContent(
      tester,
      bundle: bundle,
      desktop: true,
      initialSeriesName: 'Series Alpha',
      enableRefresh: true,
      wrap: (child) => AppPageRefreshRegistrarScope(
        registrar: AppPageRefreshRegistrar(
          register: refreshCallbacks.add,
          unregister: refreshCallbacks.remove,
        ),
        child: Scaffold(body: child),
      ),
    );

    expect(refreshCallbacks, hasLength(1));
    unawaited(refreshCallbacks.single());
    await _pumpFrames(tester);

    expect(find.byKey(const Key('movie-summary-card-ABC-001')), findsNothing);
    expect(find.byKey(const Key('movie-summary-card-ABC-002')), findsOneWidget);
    expect(_seriesRequests(bundle), hasLength(2));
    expect(tester.takeException(), isNull);
  });

  testWidgets('series refresh keeps data and reports its failure', (
    tester,
  ) async {
    _enqueueSeriesPage(
      bundle,
      movies: <Map<String, dynamic>>[
        _movie('ABC-001', seriesName: 'Series Alpha'),
      ],
      total: 1,
    );
    bundle.adapter.enqueueJson(
      method: 'POST',
      path: '/movies/by-series',
      statusCode: 500,
      body: <String, dynamic>{'detail': 'boom'},
    );

    var failures = 0;
    final refreshCallbacks = <Future<void> Function()>[];
    await _pumpSeriesContent(
      tester,
      bundle: bundle,
      desktop: true,
      initialSeriesName: 'Series Alpha',
      enableRefresh: true,
      onRefreshFailure: (_) => failures += 1,
      wrap: (child) => AppPageRefreshRegistrarScope(
        registrar: AppPageRefreshRegistrar(
          register: refreshCallbacks.add,
          unregister: refreshCallbacks.remove,
        ),
        child: Scaffold(body: child),
      ),
    );

    unawaited(refreshCallbacks.single());
    await _pumpFrames(tester);

    expect(failures, 1);
    expect(find.byKey(const Key('movie-summary-card-ABC-001')), findsOneWidget);
    expect(_seriesRequests(bundle), hasLength(2));
    expect(tester.takeException(), isNull);
  });

  testWidgets('series initial error retries the first page', (tester) async {
    bundle.adapter.enqueueJson(
      method: 'POST',
      path: '/movies/by-series',
      statusCode: 500,
      body: <String, dynamic>{'detail': 'boom'},
    );
    _enqueueSeriesPage(
      bundle,
      movies: <Map<String, dynamic>>[
        _movie('ABC-001', seriesName: 'Series Alpha'),
      ],
      total: 1,
    );

    await _pumpSeriesContent(
      tester,
      bundle: bundle,
      desktop: true,
      initialSeriesName: 'Series Alpha',
    );

    final retry = find.byKey(const Key('series-movies-initial-error-retry'));
    expect(retry, findsOneWidget);
    await tester.tap(retry);
    await _pumpFrames(tester);

    expect(find.byKey(const Key('movie-summary-card-ABC-001')), findsOneWidget);
    expect(_seriesRequests(bundle), hasLength(2));
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'mobile series reports its title and long-presses into selection',
    (tester) async {
      _enqueueSeriesPage(
        bundle,
        movies: <Map<String, dynamic>>[
          _movie('ABC-001', seriesName: 'Series Mobile'),
        ],
        total: 1,
      );

      final title = ValueNotifier<String?>(null);
      addTearDown(title.dispose);

      await _pumpSeriesContent(
        tester,
        bundle: bundle,
        desktop: false,
        hoistTitleToSubpageShell: true,
        wrap: (child) => Scaffold(
          body: AppMobileSubpageTitle(notifier: title, child: child),
        ),
      );

      expect(title.value, 'Series Mobile');
      expect(
        find.byKey(const Key('series-movies-import-button')),
        findsOneWidget,
      );

      await tester.longPress(
        find.byKey(const Key('movie-summary-card-ABC-001')),
      );
      await _pumpFrames(tester);

      expect(
        find.byKey(const Key('series-movies-exit-selection-button')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('series-movies-batch-bottom-bar')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );
}

Future<void> _pumpSeriesContent(
  WidgetTester tester, {
  required TestApiBundle bundle,
  required bool desktop,
  String? initialSeriesName,
  bool hoistTitleToSubpageShell = false,
  bool enableRefresh = false,
  void Function(BuildContext context)? onRefreshFailure,
  Widget Function(Widget child)? wrap,
}) async {
  tester.view.physicalSize = desktop
      ? const Size(1100, 760)
      : const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ProviderScope(
      // 关闭 Riverpod 3 的全局自动重试，确保本用例走用户显式重试路径。
      retry: (_, _) => null,
      overrides: bundle.riverpodOverrides(),
      child: MaterialApp(
        theme: desktop
            ? buildSakuraDesktopThemeData()
            : buildSakuraMobileThemeData(),
        locale: const Locale('zh'),
        localizationsDelegates: <LocalizationsDelegate<dynamic>>[
          AppLocalizations.delegate,
          ...GlobalMaterialLocalizations.delegates,
        ],
        supportedLocales: const <Locale>[Locale('zh'), Locale('en')],
        home: AppPlatformScope(
          platform: desktop ? AppPlatform.desktop : AppPlatform.mobile,
          child:
              wrap?.call(
                _seriesContent(
                  desktop: desktop,
                  initialSeriesName: initialSeriesName,
                  hoistTitleToSubpageShell: hoistTitleToSubpageShell,
                  enableRefresh: enableRefresh,
                  onRefreshFailure: onRefreshFailure,
                ),
              ) ??
              Scaffold(
                body: _seriesContent(
                  desktop: desktop,
                  initialSeriesName: initialSeriesName,
                  hoistTitleToSubpageShell: hoistTitleToSubpageShell,
                  enableRefresh: enableRefresh,
                  onRefreshFailure: onRefreshFailure,
                ),
              ),
        ),
      ),
    ),
  );
  await _pumpFrames(tester);
}

Widget _seriesContent({
  required bool desktop,
  required String? initialSeriesName,
  required bool hoistTitleToSubpageShell,
  required bool enableRefresh,
  required void Function(BuildContext context)? onRefreshFailure,
}) {
  return SeriesMoviesContent(
    seriesId: _seriesId,
    initialSeriesName: initialSeriesName,
    contentKey: Key(
      desktop ? 'desktop-series-movies-page' : 'mobile-series-movies-page',
    ),
    totalKey: Key(
      desktop ? 'desktop-series-movies-total' : 'mobile-series-movies-total',
    ),
    sectionSpacing: 12,
    onMovieTap: (_, _) {},
    bodyBuilder: (_, scrollController, sliver, _) => CustomScrollView(
      controller: scrollController,
      slivers: <Widget>[sliver],
    ),
    enableRefresh: enableRefresh,
    onRefreshFailure: onRefreshFailure,
    useMobileSelectionLayout: !desktop,
    hoistTitleToSubpageShell: hoistTitleToSubpageShell,
  );
}

void _enqueueSeriesPage(
  TestApiBundle bundle, {
  required List<Map<String, dynamic>> movies,
  required int total,
  int page = 1,
}) {
  bundle.adapter.enqueueJson(
    method: 'POST',
    path: '/movies/by-series',
    body: <String, dynamic>{
      'items': movies,
      'page': page,
      'page_size': _pageSize,
      'total': total,
    },
  );
}

List<RecordedRequest> _seriesRequests(TestApiBundle bundle) {
  return bundle.adapter.requests
      .where((request) => request.path == '/movies/by-series')
      .toList(growable: false);
}

Map<String, dynamic> _movie(String movieNumber, {required String seriesName}) {
  return <String, dynamic>{
    'id': movieNumber.hashCode,
    'javdb_id': movieNumber,
    'movie_number': movieNumber,
    'title': movieNumber,
    'series_id': _seriesId,
    'series_name': seriesName,
    'cover_image': null,
    'release_date': null,
    'duration_minutes': 120,
    'heat': 0,
    'is_subscribed': false,
    'can_play': true,
  };
}

Future<void> _pumpFrames(WidgetTester tester) async {
  for (var index = 0; index < 20; index++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}
