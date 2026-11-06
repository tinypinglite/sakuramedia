import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show KeepAliveLink;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/app/page_cache_keys.dart';
import 'package:sakuramedia/app/riverpod_page_cache.dart';
import 'package:sakuramedia/core/session/session_store.dart';
import 'package:sakuramedia/features/search/presentation/catalog_search_page.dart';
import 'package:sakuramedia/l10n/app_localizations.dart';
import 'package:sakuramedia/routes/app_route_paths.dart';
import 'package:sakuramedia/routes/app_routes.dart';
import 'package:sakuramedia/theme.dart';

import '../../../support/test_api_bundle.dart';

const _movieNumber = 'ABP-123';

Map<String, dynamic> _moviePage() => <String, dynamic>{
  'items': <Map<String, dynamic>>[
    <String, dynamic>{
      'id': 11,
      'javdb_id': 'MovieA1',
      'movie_number': _movieNumber,
      'title': 'Movie 1',
      'cover_image': null,
      'release_date': null,
      'duration_minutes': 120,
      'is_subscribed': false,
      'can_play': true,
    },
  ],
  'page': 1,
  'page_size': 50,
  'total': 1,
};

Map<String, dynamic> _emptyPage() => <String, dynamic>{
  'items': <dynamic>[],
  'page': 1,
  'page_size': 50,
  'total': 0,
};

class _RecordingPageCache extends RiverpodPageCache {
  final List<String> keys = <String>[];

  @override
  RiverpodPageHandle obtain({
    required String key,
    required List<KeepAliveLink> Function() resolveLinks,
  }) {
    keys.add(key);
    return super.obtain(key: key, resolveLinks: resolveLinks);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  for (final mobile in <bool>[false, true]) {
    testWidgets(
      '${mobile ? 'mobile' : 'desktop'} search keeps its entry behavior',
      (tester) async {
        final session = SessionStore.inMemory();
        await session.saveBaseUrl('https://api.example.com');
        await session.saveTokens(
          accessToken: 'test',
          refreshToken: 'test',
          expiresAt: DateTime(2099),
        );
        final bundle = await createTestApiBundle(session);
        addTearDown(bundle.dispose);
        bundle.adapter.enqueueJson(
          method: 'GET',
          path: '/movies',
          body: _moviePage(),
        );
        bundle.adapter.enqueueJson(
          method: 'GET',
          path: '/actors',
          body: _emptyPage(),
        );

        final pageCache = _RecordingPageCache();
        final router = _buildSearchRouter(mobile: mobile);
        addTearDown(router.dispose);
        await _pumpSearchApp(
          tester,
          router: router,
          bundle: bundle,
          pageCache: pageCache,
          mobile: mobile,
        );

        expect(
          find.byKey(const Key('catalog-search-page-field')),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('catalog-search-page-input')),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('catalog-search-page-submit')),
          findsOneWidget,
        );
        expect(
          pageCache.keys,
          contains(
            mobile
                ? mobileSearchPageCacheKey(mobileSearchPath)
                : desktopSearchPageCacheKey(desktopSearchPath),
          ),
        );

        expect(router.canPop(), isFalse);
        await tester.tap(find.byKey(const Key('catalog-search-page-submit')));
        await tester.pumpAndSettle();
        expect(router.canPop(), mobile ? isFalse : isTrue);
        if (!mobile) {
          router.pop();
          await tester.pumpAndSettle();
        }

        await tester.enterText(
          find.byKey(const Key('catalog-search-page-input')),
          _movieNumber,
        );
        await tester.tap(find.byKey(const Key('catalog-search-page-submit')));
        await tester.pumpAndSettle();

        final queryLocation = mobile
            ? MobileRoutes.search(query: _movieNumber).location
            : DesktopRoutes.search(query: _movieNumber).location;
        expect(
          router.routeInformationProvider.value.uri.toString(),
          queryLocation,
        );
        expect(
          pageCache.keys,
          contains(
            mobile
                ? mobileSearchPageCacheKey(queryLocation)
                : desktopSearchPageCacheKey(queryLocation),
          ),
        );

        await tester.tap(
          find.byKey(const Key('movie-summary-card-$_movieNumber')),
        );
        await tester.pumpAndSettle();
        final detailLocation = mobile
            ? MobileRoutes.movieDetail(movieNumber: _movieNumber).location
            : DesktopRoutes.movieDetail(movieNumber: _movieNumber).location;
        expect(router.routeInformationProvider.value.uri.path, detailLocation);

        router.pop();
        await tester.pumpAndSettle();
        expect(
          router.routeInformationProvider.value.uri.toString(),
          queryLocation,
        );
      },
    );
  }
}

GoRouter _buildSearchRouter({required bool mobile}) {
  final searchPath = mobile ? mobileSearchPath : desktopSearchPath;
  final detailPrefix = mobile
      ? '/mobile/library/movies'
      : '/desktop/library/movies';
  return GoRouter(
    initialLocation: searchPath,
    routes: <RouteBase>[
      GoRoute(
        path: searchPath,
        builder: (context, state) =>
            _searchPage(mobile: mobile, initialQuery: ''),
      ),
      GoRoute(
        path: '$searchPath/:query',
        builder: (context, state) => _searchPage(
          mobile: mobile,
          initialQuery: state.pathParameters['query']!,
        ),
      ),
      GoRoute(
        path: '$detailPrefix/:movieNumber',
        builder: (context, state) => Text(state.pathParameters['movieNumber']!),
      ),
    ],
  );
}

Widget _searchPage({required bool mobile, required String initialQuery}) {
  return CatalogSearchPage(initialQuery: initialQuery, mobile: mobile);
}

Future<void> _pumpSearchApp(
  WidgetTester tester, {
  required GoRouter router,
  required TestApiBundle bundle,
  required RiverpodPageCache pageCache,
  required bool mobile,
}) async {
  tester.view.physicalSize = mobile
      ? const Size(390, 844)
      : const Size(1100, 760);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ProviderScope(
      overrides: bundle.riverpodOverrides(pageStateCache: pageCache),
      child: MaterialApp.router(
        theme: sakuraThemeData,
        locale: const Locale('zh'),
        localizationsDelegates: <LocalizationsDelegate<dynamic>>[
          AppLocalizations.delegate,
          ...GlobalMaterialLocalizations.delegates,
        ],
        supportedLocales: const <Locale>[Locale('zh'), Locale('en')],
        routerConfig: router,
      ),
    ),
  );
  await tester.pumpAndSettle();
}
