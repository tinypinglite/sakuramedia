import 'package:flutter/material.dart';
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
          fallbackPath: '/mobile/overview',
          child: SizedBox.shrink(),
        ),
      ),
    );

    expect(find.byKey(const Key('mobile-subpage-topbar')), findsOneWidget);
    expect(find.text('播放列表详情'), findsOneWidget);
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
                fallbackPath: '/home',
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
                fallbackPath: '/home',
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
                fallbackPath: '/home',
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
                fallbackPath: '/home',
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
}
