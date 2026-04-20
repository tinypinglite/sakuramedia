import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/app_shell/app_mobile_subpage_shell.dart';

void main() {
  testWidgets('mobile subpage shell renders app bar title and no bottom nav', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: sakuraThemeData,
        home: const AppMobileSubpageShell(
          title: '播放列表详情',
          defaultLocation: '/mobile/overview',
          child: SizedBox.shrink(),
        ),
      ),
    );

    final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
    final appBar = tester.widget<AppBar>(find.byType(AppBar));
    final rootSurface = tester.widget<ColoredBox>(
      find.byKey(const Key('mobile-subpage-root-surface')),
    );
    final overlayStyle =
        tester
            .widget<AnnotatedRegion<SystemUiOverlayStyle>>(
              find.byKey(const Key('mobile-subpage-system-overlay')),
            )
            .value;

    expect(find.byKey(const Key('mobile-subpage-safe-area')), findsOneWidget);
    expect(find.byKey(const Key('mobile-subpage-topbar')), findsOneWidget);
    expect(find.text('播放列表详情'), findsOneWidget);
    final titleText = tester.widget<Text>(find.text('播放列表详情'));
    expect(titleText.style?.fontSize, sakuraThemeData.appTextScale.s14);
    expect(rootSurface.color, sakuraThemeData.appColors.surfaceCard);
    expect(scaffold.backgroundColor, sakuraThemeData.appColors.surfaceCard);
    expect(appBar.backgroundColor, sakuraThemeData.appColors.surfaceCard);
    expect(overlayStyle.statusBarColor, sakuraThemeData.appColors.surfaceCard);
    expect(overlayStyle.statusBarIconBrightness, Brightness.dark);
    expect(overlayStyle.statusBarBrightness, Brightness.light);
    expect(
      overlayStyle.systemNavigationBarColor,
      sakuraThemeData.appColors.surfaceCard,
    );
    expect(overlayStyle.systemNavigationBarIconBrightness, Brightness.dark);
    expect(
      overlayStyle.systemNavigationBarDividerColor,
      sakuraThemeData.appColors.divider,
    );
    expect(find.byKey(const Key('mobile-bottom-navigation')), findsNothing);
  });

  testWidgets('mobile subpage shell back pops when route stack exists', (
    tester,
  ) async {
    final router = GoRouter(
      initialLocation: '/home',
      routes: [
        GoRoute(
          path: '/home',
          builder:
              (context, state) => Scaffold(
                body: Center(
                  child: TextButton(
                    onPressed: () => context.push('/sub'),
                    child: const Text('open-sub'),
                  ),
                ),
              ),
        ),
        ShellRoute(
          builder:
              (context, state, child) => AppMobileSubpageShell(
                title: '子页面',
                defaultLocation: '/home',
                child: child,
              ),
          routes: [
            GoRoute(
              path: '/sub',
              builder:
                  (_, __) => const Scaffold(
                    body: Text('sub-page', textDirection: TextDirection.ltr),
                  ),
            ),
          ],
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      MaterialApp.router(theme: sakuraThemeData, routerConfig: router),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('open-sub'));
    await tester.pumpAndSettle();
    expect(find.text('sub-page'), findsOneWidget);

    await tester.tap(find.byKey(const Key('mobile-subpage-back-button')));
    await tester.pumpAndSettle();

    expect(router.routeInformationProvider.value.uri.path, '/home');
  });

  testWidgets('mobile subpage shell system back pops when route stack exists', (
    tester,
  ) async {
    final router = GoRouter(
      initialLocation: '/home',
      routes: [
        GoRoute(
          path: '/home',
          builder:
              (context, state) => Scaffold(
                body: Center(
                  child: TextButton(
                    onPressed: () => context.push('/sub'),
                    child: const Text('open-sub'),
                  ),
                ),
              ),
        ),
        ShellRoute(
          builder:
              (context, state, child) => AppMobileSubpageShell(
                title: '子页面',
                defaultLocation: '/home',
                child: child,
              ),
          routes: [
            GoRoute(
              path: '/sub',
              builder:
                  (_, __) => const Scaffold(
                    body: Text('sub-page', textDirection: TextDirection.ltr),
                  ),
            ),
          ],
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      MaterialApp.router(theme: sakuraThemeData, routerConfig: router),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('open-sub'));
    await tester.pumpAndSettle();
    expect(find.text('sub-page'), findsOneWidget);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(router.routeInformationProvider.value.uri.path, '/home');
  });

  testWidgets('mobile subpage shell back uses fallback on deep link', (
    tester,
  ) async {
    final router = GoRouter(
      initialLocation: '/sub',
      routes: [
        GoRoute(
          path: '/home',
          builder:
              (_, __) => const Scaffold(
                body: Text('home-page', textDirection: TextDirection.ltr),
              ),
        ),
        ShellRoute(
          builder:
              (context, state, child) => AppMobileSubpageShell(
                title: '子页面',
                defaultLocation: '/home',
                child: child,
              ),
          routes: [
            GoRoute(
              path: '/sub',
              builder:
                  (_, __) => const Scaffold(
                    body: Text('sub-page', textDirection: TextDirection.ltr),
                  ),
            ),
          ],
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      MaterialApp.router(theme: sakuraThemeData, routerConfig: router),
    );
    await tester.pumpAndSettle();

    expect(find.text('sub-page'), findsOneWidget);
    await tester.tap(find.byKey(const Key('mobile-subpage-back-button')));
    await tester.pumpAndSettle();

    expect(router.routeInformationProvider.value.uri.path, '/home');
    expect(find.text('home-page'), findsOneWidget);
  });

  testWidgets('mobile subpage shell system back uses fallback on deep link', (
    tester,
  ) async {
    final router = GoRouter(
      initialLocation: '/sub',
      routes: [
        GoRoute(
          path: '/home',
          builder:
              (_, __) => const Scaffold(
                body: Text('home-page', textDirection: TextDirection.ltr),
              ),
        ),
        ShellRoute(
          builder:
              (context, state, child) => AppMobileSubpageShell(
                title: '子页面',
                defaultLocation: '/home',
                child: child,
              ),
          routes: [
            GoRoute(
              path: '/sub',
              builder:
                  (_, __) => const Scaffold(
                    body: Text('sub-page', textDirection: TextDirection.ltr),
                  ),
            ),
          ],
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      MaterialApp.router(theme: sakuraThemeData, routerConfig: router),
    );
    await tester.pumpAndSettle();

    expect(find.text('sub-page'), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(router.routeInformationProvider.value.uri.path, '/home');
    expect(find.text('home-page'), findsOneWidget);
  });

  testWidgets('mobile subpage shell applies custom body padding', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: sakuraThemeData,
        home: AppMobileSubpageShell(
          title: '子页面',
          defaultLocation: '/home',
          bodyPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Container(key: const Key('subpage-body-child')),
        ),
      ),
    );

    final bodyPadding = tester.widget<Padding>(
      find.byKey(const Key('mobile-subpage-body-padding')),
    );

    expect(
      bodyPadding.padding,
      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
    );
  });
}
