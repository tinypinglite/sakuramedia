import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:sakuramedia/app/app.dart';
import 'package:sakuramedia/app/app_platform.dart';
import 'package:sakuramedia/core/session/session_store.dart';
import 'package:sakuramedia/routes/app_navigation.dart';

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
    expect(find.text('路径: $mobileActorsPath'), findsOneWidget);

    rebuildNotifier.value += 1;
    await tester.pumpAndSettle();

    final rebuiltRouter = _routerFrom(tester);
    expect(identical(rebuiltRouter, initialRouter), isTrue);
    expect(
      rebuiltRouter.routeInformationProvider.value.uri.path,
      mobileActorsPath,
    );
    expect(find.byKey(const Key('mobile-bottom-navigation')), findsOneWidget);
    expect(find.text('路径: $mobileActorsPath'), findsOneWidget);
  });
}

GoRouter _routerFrom(WidgetTester tester) {
  final materialApp = tester.widget<MaterialApp>(find.byType(MaterialApp));
  return materialApp.routerConfig! as GoRouter;
}
