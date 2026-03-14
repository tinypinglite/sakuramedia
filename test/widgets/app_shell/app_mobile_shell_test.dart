import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:sakuramedia/routes/app_route_spec.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/app_shell/app_mobile_shell.dart';

void main() {
  const navGroups = [
    AppNavGroup(
      id: 'overview',
      label: '概览',
      icon: Icons.space_dashboard_outlined,
      isCollapsible: false,
      items: [
        AppNavItem(
          name: 'mobile-overview',
          label: '概览',
          path: '/mobile/overview',
          icon: Icons.space_dashboard_outlined,
          description: 'overview',
        ),
      ],
    ),
    AppNavGroup(
      id: 'movies',
      label: '影片',
      icon: Icons.movie_creation_outlined,
      isCollapsible: false,
      items: [
        AppNavItem(
          name: 'mobile-library/movies',
          label: '影片',
          path: '/mobile/library/movies',
          icon: Icons.movie_creation_outlined,
          description: 'movies',
        ),
      ],
    ),
    AppNavGroup(
      id: 'actors',
      label: '女优',
      icon: Icons.face_retouching_natural_outlined,
      isCollapsible: false,
      items: [
        AppNavItem(
          name: 'mobile-library/actors',
          label: '女优',
          path: '/mobile/library/actors',
          icon: Icons.face_retouching_natural_outlined,
          description: 'actors',
        ),
      ],
    ),
    AppNavGroup(
      id: 'rankings',
      label: '榜单',
      icon: Icons.local_fire_department_outlined,
      isCollapsible: false,
      items: [
        AppNavItem(
          name: 'mobile-rankings',
          label: '榜单',
          path: '/mobile/rankings',
          icon: Icons.local_fire_department_outlined,
          description: 'rankings',
        ),
      ],
    ),
  ];

  testWidgets('mobile shell resolves selected tab from current path', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: sakuraThemeData,
        home: const AppMobileShell(
          currentPath: '/mobile/library/movies',
          navGroups: navGroups,
          child: SizedBox.shrink(),
        ),
      ),
    );

    final tabBar = tester.widget<CupertinoTabBar>(find.byType(CupertinoTabBar));
    expect(tabBar.currentIndex, 1);
    expect(tabBar.height, 52);
  });

  testWidgets('mobile shell navigates when tapping bottom destination', (
    tester,
  ) async {
    final router = GoRouter(
      initialLocation: '/mobile/overview',
      routes: [
        ShellRoute(
          builder:
              (context, state, child) => AppMobileShell(
                currentPath: state.uri.path,
                navGroups: navGroups,
                child: child,
              ),
          routes: [
            GoRoute(
              path: '/mobile/overview',
              builder: (context, state) => const SizedBox.shrink(),
            ),
            GoRoute(
              path: '/mobile/library/movies',
              builder: (context, state) => const SizedBox.shrink(),
            ),
            GoRoute(
              path: '/mobile/library/actors',
              builder: (context, state) => const SizedBox.shrink(),
            ),
            GoRoute(
              path: '/mobile/rankings',
              builder: (context, state) => const SizedBox.shrink(),
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

    await tester.tap(find.text('女优'));
    await tester.pumpAndSettle();

    expect(
      router.routeInformationProvider.value.uri.path,
      '/mobile/library/actors',
    );
  });
}
