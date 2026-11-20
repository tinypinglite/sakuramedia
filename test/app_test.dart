import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:sakuramedia/app/app.dart';
import 'package:sakuramedia/app/app_platform.dart';
import 'package:sakuramedia/core/session/session_store.dart';
import 'package:sakuramedia/routes/app_route_paths.dart';
import 'package:sakuramedia/widgets/shell/tv/app_tv_shell.dart';

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

    rebuildNotifier.value += 1;
    await tester.pumpAndSettle();

    final rebuiltRouter = _routerFrom(tester);
    expect(identical(rebuiltRouter, initialRouter), isTrue);
    expect(
      rebuiltRouter.routeInformationProvider.value.uri.path,
      mobileActorsPath,
    );
  });

  testWidgets('MyApp boots the TV shell on the TV route tree', (
    WidgetTester tester,
  ) async {
    final sessionStore = SessionStore.inMemory();
    addTearDown(sessionStore.dispose);
    await sessionStore.saveTokens(
      accessToken: 'access-token',
      refreshToken: 'refresh-token',
      expiresAt: DateTime.utc(2026, 1, 1),
    );

    await tester.pumpWidget(
      MyApp(platformOverride: AppPlatform.tv, sessionStore: sessionStore),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    final router = _routerFrom(tester);
    expect(router.routeInformationProvider.value.uri.path, tvHomePath);
    expect(find.byType(AppTvShell), findsOneWidget);
  });
}

GoRouter _routerFrom(WidgetTester tester) {
  final materialApp = tester.widget<MaterialApp>(find.byType(MaterialApp));
  return materialApp.routerConfig! as GoRouter;
}
