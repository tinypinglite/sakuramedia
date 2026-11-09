import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sakuramedia/app/app_platform.dart';
import 'package:sakuramedia/app/first_login_performance_hint.dart';
import 'package:sakuramedia/app/onboarding_store.dart';
import 'package:sakuramedia/core/session/session_store.dart';
import 'package:sakuramedia/l10n/app_localizations.dart';
import 'package:sakuramedia/theme.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('首次登录后展示一次性能提示', (tester) async {
    final sessionStore = SessionStore.inMemory();
    addTearDown(sessionStore.dispose);
    final onboardingStore = InMemoryOnboardingStore();
    final navigatorKey = GlobalKey<NavigatorState>();

    await _pumpHost(
      tester,
      sessionStore: sessionStore,
      onboardingStore: onboardingStore,
      navigatorKey: navigatorKey,
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('first-login-performance-hint')), findsNothing);

    await _signIn(sessionStore);
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('first-login-performance-hint')),
      findsOneWidget,
    );
    expect(onboardingStore.hasSeenPerformanceHint, isTrue);

    await tester.tap(
      find.byKey(const Key('first-login-performance-hint-dismiss')),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('first-login-performance-hint')), findsNothing);

    await sessionStore.clearSession();
    await tester.pump();
    await _signIn(sessionStore);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('first-login-performance-hint')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('启动时已经登录不会补弹性能提示', (tester) async {
    final sessionStore = SessionStore.inMemory();
    addTearDown(sessionStore.dispose);
    await _signIn(sessionStore);
    final onboardingStore = InMemoryOnboardingStore();
    final navigatorKey = GlobalKey<NavigatorState>();

    await _pumpHost(
      tester,
      sessionStore: sessionStore,
      onboardingStore: onboardingStore,
      navigatorKey: navigatorKey,
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('first-login-performance-hint')), findsNothing);
    expect(onboardingStore.hasSeenPerformanceHint, isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets('性能提示会在停留一段时间后自动关闭', (tester) async {
    final sessionStore = SessionStore.inMemory();
    addTearDown(sessionStore.dispose);
    final onboardingStore = InMemoryOnboardingStore();
    final navigatorKey = GlobalKey<NavigatorState>();

    await _pumpHost(
      tester,
      sessionStore: sessionStore,
      onboardingStore: onboardingStore,
      navigatorKey: navigatorKey,
    );
    await tester.pumpAndSettle();
    await _signIn(sessionStore);
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('first-login-performance-hint')),
      findsOneWidget,
    );

    await tester.pump(const Duration(seconds: 11));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('first-login-performance-hint')), findsNothing);
    expect(tester.takeException(), isNull);
  });
}

Future<void> _signIn(SessionStore sessionStore) {
  return sessionStore.saveTokens(
    accessToken: 'access-token',
    refreshToken: 'refresh-token',
    expiresAt: DateTime(2099),
  );
}

Future<void> _pumpHost(
  WidgetTester tester, {
  required SessionStore sessionStore,
  required InMemoryOnboardingStore onboardingStore,
  required GlobalKey<NavigatorState> navigatorKey,
}) {
  return tester.pumpWidget(
    FirstLoginPerformanceHintHost(
      sessionStore: sessionStore,
      onboardingStore: onboardingStore,
      platform: AppPlatform.desktop,
      navigatorKey: navigatorKey,
      isLoginPage: () => false,
      child: MaterialApp(
        navigatorKey: navigatorKey,
        theme: sakuraDesktopThemeData,
        locale: const Locale('zh'),
        localizationsDelegates: <LocalizationsDelegate<dynamic>>[
          AppLocalizations.delegate,
          ...GlobalMaterialLocalizations.delegates,
        ],
        supportedLocales: const <Locale>[Locale('zh'), Locale('en')],
        home: const Scaffold(body: Text('home')),
      ),
    ),
  );
}
