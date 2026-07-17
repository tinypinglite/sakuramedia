import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:sakuramedia/app/app.dart';
import 'package:sakuramedia/app/app_platform.dart';
import 'package:sakuramedia/core/session/session_store.dart';
import 'package:sakuramedia/routes/app_navigation.dart';
import 'package:sakuramedia/theme.dart';

void main() {
  testWidgets('MyApp preserves router instance across parent rebuilds', (
    WidgetTester tester,
  ) async {
    final sessionStore = SessionStore.inMemory();
    addTearDown(sessionStore.dispose);
    await sessionStore.saveTokens(
      accessToken: 'access-token',
      refreshToken: 'refresh-token',
      expiresAt: DateTime.utc(2026, 1, 1),
    );

    final rebuildNotifier = ValueNotifier<int>(0);
    addTearDown(rebuildNotifier.dispose);

    await tester.pumpWidget(
      ValueListenableBuilder<int>(
        valueListenable: rebuildNotifier,
        builder: (context, value, child) {
          return MyApp(
            platformOverride: AppPlatform.mobile,
            sessionStore: sessionStore,
          );
        },
      ),
    );
    await tester.pumpAndSettle();

    final initialRouter = _routerFrom(tester);
    expect(
      initialRouter.routeInformationProvider.value.uri.path,
      mobileOverviewPath,
    );

    initialRouter.go(mobileActorsPath);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('mobile-bottom-navigation')), findsOneWidget);
    expect(find.byKey(const Key('mobile-actors-page')), findsOneWidget);

    rebuildNotifier.value += 1;
    await tester.pumpAndSettle();

    final rebuiltRouter = _routerFrom(tester);
    expect(identical(rebuiltRouter, initialRouter), isTrue);
    expect(
      rebuiltRouter.routeInformationProvider.value.uri.path,
      mobileActorsPath,
    );
    expect(find.byKey(const Key('mobile-bottom-navigation')), findsOneWidget);
    expect(find.byKey(const Key('mobile-actors-page')), findsOneWidget);
  });

  testWidgets('MyApp uses platform-specific theme mapping', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MyApp(platformOverride: AppPlatform.mobile));
    await tester.pumpAndSettle();

    var materialApp = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(
      materialApp.theme?.appTextScale.s14,
      sakuraMobileThemeData.appTextScale.s14,
    );

    await tester.pumpWidget(const MyApp(platformOverride: AppPlatform.desktop));
    await tester.pumpAndSettle();

    materialApp = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(
      materialApp.theme?.appTextScale.s14,
      sakuraDesktopThemeData.appTextScale.s14,
    );
  });

  testWidgets('MyApp shows the platform notice once for web', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MyApp(platformOverride: AppPlatform.web));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('web-platform-notice-dialog')), findsOneWidget);
    expect(find.text('建议使用 SakuraMedia 客户端'), findsOneWidget);
    expect(find.text('我知道了'), findsOneWidget);

    await tester.tap(find.text('我知道了'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('web-platform-notice-dialog')), findsNothing);

    final materialApp = tester.widget<MaterialApp>(find.byType(MaterialApp));
    (materialApp.routerConfig! as GoRouter).go(desktopOverviewPath);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('web-platform-notice-dialog')), findsNothing);
  });

  testWidgets('MyApp does not show the platform notice outside web', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MyApp(platformOverride: AppPlatform.desktop));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('web-platform-notice-dialog')), findsNothing);
  });
}

GoRouter _routerFrom(WidgetTester tester) {
  final materialApp = tester.widget<MaterialApp>(find.byType(MaterialApp));
  return materialApp.routerConfig! as GoRouter;
}
