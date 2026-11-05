import 'package:flutter_riverpod/flutter_riverpod.dart' show ProviderScope;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sakuramedia/core/session/session_store.dart';
import 'package:sakuramedia/l10n/app_localizations.dart';
import 'package:sakuramedia/routes/app_route_paths.dart';
import 'package:sakuramedia/routes/app_router.dart';
import 'package:sakuramedia/theme.dart';

import '../support/test_api_bundle.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  testWidgets('desktop router redirects root to overview', (tester) async {
    final sessionStore = await _loggedInSessionStore();
    final bundle = await createTestApiBundle(sessionStore);
    addTearDown(bundle.dispose);
    final router = buildDesktopRouter(sessionStore: sessionStore);

    await _pumpRouter(tester, router: router, bundle: bundle);
    await tester.pumpAndSettle();

    expect(
      router.routeInformationProvider.value.uri.toString(),
      desktopOverviewPath,
    );
  });

  testWidgets('unauthenticated user is redirected to login', (tester) async {
    final sessionStore = SessionStore.inMemory();
    final bundle = await createTestApiBundle(sessionStore);
    addTearDown(bundle.dispose);
    final router = buildDesktopRouter(sessionStore: sessionStore);

    await _pumpRouter(tester, router: router, bundle: bundle);

    expect(router.routeInformationProvider.value.uri.path, loginPath);
  });

  testWidgets('authenticated user visiting login is redirected to overview', (
    tester,
  ) async {
    final sessionStore = await _loggedInSessionStore();
    final bundle = await createTestApiBundle(sessionStore);
    addTearDown(bundle.dispose);
    final router = buildDesktopRouter(sessionStore: sessionStore);

    await _pumpRouter(tester, router: router, bundle: bundle);
    router.go(loginPath);
    await tester.pumpAndSettle();

    expect(router.routeInformationProvider.value.uri.path, desktopOverviewPath);
  });

  testWidgets('authenticated user can access protected mobile routes', (
    tester,
  ) async {
    final sessionStore = await _loggedInSessionStore();
    final bundle = await createTestApiBundle(sessionStore);
    addTearDown(bundle.dispose);
    final router = buildMobileRouter(sessionStore: sessionStore);

    await _pumpRouter(tester, router: router, bundle: bundle);
    router.go('/mobile/library/movies');
    await tester.pumpAndSettle();

    expect(
      router.routeInformationProvider.value.uri.path,
      '/mobile/library/movies',
    );
  });
}

Future<SessionStore> _loggedInSessionStore() async {
  final store = SessionStore.inMemory();
  await store.saveBaseUrl('https://api.example.com');
  await store.saveTokens(
    accessToken: 'access-token',
    refreshToken: 'refresh-token',
    expiresAt: DateTime.parse('2026-03-10T12:00:00Z'),
  );
  return store;
}

Future<void> _pumpRouter(
  WidgetTester tester, {
  required GoRouter router,
  required TestApiBundle bundle,
}) {
  return tester.pumpWidget(
    ProviderScope(
      overrides: bundle.riverpodOverrides(),
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
}
