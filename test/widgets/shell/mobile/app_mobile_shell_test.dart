import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/routes/app_route.dart';
import 'package:sakuramedia/routes/app_route_spec.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/shell/mobile/app_mobile_shell.dart';

void main() {
  testWidgets('tapping a destination invokes the optional callback', (
    tester,
  ) async {
    final selected = <int>[];
    await tester.pumpWidget(
      MaterialApp(
        theme: sakuraMobileThemeData,
        home: MediaQuery(
          data: const MediaQueryData(size: Size(390, 844), highContrast: true),
          child: AppMobileShell(
            currentPath: '/mobile/overview',
            currentIndex: 0,
            navItems: _navItems(),
            onDestinationSelected: selected.add,
            child: const SizedBox.shrink(),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Movies'));
    expect(selected, <int>[1]);
  });

  testWidgets('tapping without a callback is a no-op outside GoRouter', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: sakuraMobileThemeData,
        home: MediaQuery(
          data: const MediaQueryData(size: Size(390, 844), highContrast: true),
          child: AppMobileShell(
            currentPath: '/mobile/overview',
            currentIndex: 0,
            navItems: _navItems(),
            child: const SizedBox.shrink(),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Movies'));
    expect(tester.takeException(), isNull);
  });

  testWidgets('keeps the flat destination order in the bottom bar', (
    tester,
  ) async {
    final selected = <int>[];
    await tester.pumpWidget(
      MaterialApp(
        theme: sakuraMobileThemeData,
        home: MediaQuery(
          data: const MediaQueryData(size: Size(390, 844), highContrast: true),
          child: AppMobileShell(
            currentPath: '/mobile/overview',
            currentIndex: 0,
            navItems: _navItems(),
            onDestinationSelected: selected.add,
            child: const SizedBox.shrink(),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Actors'));
    await tester.tap(find.text('Movies'));
    expect(selected, <int>[2, 1]);
  });
}

List<AppNavItem> _navItems() {
  return <AppNavItem>[
    AppNavItem(
      routeId: AppRouteId.mobileOverview,
      name: 'overview',
      label: 'Overview',
      path: '/mobile/overview',
      icon: Icons.space_dashboard_outlined,
      description: 'Overview',
    ),
    AppNavItem(
      routeId: AppRouteId.mobileMovies,
      name: 'movies',
      label: 'Movies',
      path: '/mobile/library/movies',
      icon: Icons.movie_outlined,
      description: 'Movies',
    ),
    AppNavItem(
      routeId: AppRouteId.mobileActors,
      name: 'actors',
      label: 'Actors',
      path: '/mobile/library/actors',
      icon: Icons.people_outline_rounded,
      description: 'Actors',
    ),
  ];
}
