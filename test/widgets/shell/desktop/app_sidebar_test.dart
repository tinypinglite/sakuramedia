import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/app/providers/app_shell_providers.dart';
import 'package:sakuramedia/app/providers/app_update_check_provider.dart';
import 'package:sakuramedia/features/plugins/presentation/providers/plugins_provider.dart';
import 'package:sakuramedia/features/plugins/presentation/providers/plugins_state.dart';
import 'package:sakuramedia/l10n/app_localizations.dart';
import 'package:sakuramedia/routes/app_route.dart';
import 'package:sakuramedia/routes/app_route_spec.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/shell/desktop/app_sidebar.dart';
import 'package:sakuramedia/widgets/shell/window/app_window_drag_area.dart';

import '../../../support/pump_with_providers.dart';

void main() {
  testWidgets('keeps the primary item selected for exact and nested paths', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.linux;
    try {
      await _pumpSidebar(tester, currentPath: '/desktop/library/movies');
      expect(find.byKey(const Key('sidebar-account-card')), findsOneWidget);
      expect(_isSelected(tester, 'movies'), isTrue);
      expect(_isSelected(tester, 'actors'), isFalse);

      await _pumpSidebar(
        tester,
        currentPath: '/desktop/library/movies/ABC-001',
      );
      expect(_isSelected(tester, 'movies'), isTrue);
      expect(_isSelected(tester, 'actors'), isFalse);

      await _pumpSidebar(
        tester,
        currentPath: '/desktop/library/movies-archive',
      );
      expect(_isSelected(tester, 'movies'), isFalse);
      expect(_isSelected(tester, 'actors'), isFalse);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('compact sidebar does not build the account card', (
    tester,
  ) async {
    final container = ProviderContainer(
      overrides: <Override>[
        appShellSidebarCollapsedProvider.overrideWith(_CollapsedSidebar.new),
        pluginsProvider.overrideWith(_EmptyPlugins.new),
        appUpdateCheckProvider.overrideWith(_NoUpdates.new),
      ],
    );
    addTearDown(container.dispose);
    debugDefaultTargetPlatformOverride = TargetPlatform.linux;
    try {
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: sakuraDesktopThemeData,
            locale: const Locale('en'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const Scaffold(
              body: Row(
                children: <Widget>[
                  AppSidebar(
                    currentPath: '/desktop/library/movies',
                    navItems: _navItems,
                  ),
                  Expanded(child: SizedBox.shrink()),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(
        find.byKey(const Key('sidebar-account-card'), skipOffstage: false),
        findsNothing,
      );
      expect(container.exists(pluginsProvider), isFalse);
      // 导航区仍在 Offstage 内构建，展开时才能恢复滚动状态。
      expect(
        find.byKey(const Key('nav-group-movies'), skipOffstage: false),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('sidebar-header'), skipOffstage: false),
        findsOneWidget,
      );
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('header drag area follows the desktop chrome policy', (
    tester,
  ) async {
    try {
      for (final platform in <TargetPlatform>[
        TargetPlatform.macOS,
        TargetPlatform.windows,
      ]) {
        await _pumpSidebar(
          tester,
          currentPath: '/desktop/library/movies',
          platform: platform,
        );
        expect(find.byType(AppWindowDragArea), findsOneWidget);
      }

      await _pumpSidebar(
        tester,
        currentPath: '/desktop/library/movies',
        platform: TargetPlatform.linux,
      );
      expect(find.byType(AppWindowDragArea), findsNothing);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('compact sidebar keeps the navigation scroll offset', (
    tester,
  ) async {
    final container = ProviderContainer(
      overrides: <Override>[
        pluginsProvider.overrideWith(_EmptyPlugins.new),
        appUpdateCheckProvider.overrideWith(_NoUpdates.new),
      ],
    );
    addTearDown(container.dispose);
    debugDefaultTargetPlatformOverride = TargetPlatform.linux;
    try {
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: sakuraDesktopThemeData,
            locale: const Locale('en'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: Row(
                children: <Widget>[
                  AppSidebar(
                    currentPath: '/desktop/library/movies',
                    navItems: _manyNavItems,
                  ),
                  const Expanded(child: SizedBox.shrink()),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      final scrollView = tester.widget<SingleChildScrollView>(
        find.byType(SingleChildScrollView),
      );
      final controller = scrollView.controller!;
      controller.jumpTo(controller.position.maxScrollExtent);
      await tester.pump();
      final offsetBefore = controller.offset;
      expect(offsetBefore, greaterThan(0));

      container.read(appShellSidebarCollapsedProvider.notifier).toggle();
      await tester.pump();
      container.read(appShellSidebarCollapsedProvider.notifier).toggle();
      await tester.pump();

      expect(controller.offset, offsetBefore);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('keyboard focus adds a visible focus indicator', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.linux;
    try {
      await _pumpSidebar(
        tester,
        currentPath: '/desktop/library/actors',
        platform: TargetPlatform.linux,
      );
      final itemFinder = find.byKey(const Key('nav-group-movies'));
      final containerFinder = find.descendant(
        of: itemFinder,
        matching: find.byType(AnimatedContainer),
      );
      expect(
        tester.widget<AnimatedContainer>(containerFinder).foregroundDecoration,
        isNull,
      );

      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();

      expect(
        tester.widget<AnimatedContainer>(containerFinder).foregroundDecoration,
        isNotNull,
      );
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('renders a section header once for consecutive items', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.linux;
    try {
      await _pumpSidebar(tester, currentPath: '/desktop/library/movies');

      expect(find.byKey(const Key('sidebar-section-Browse')), findsOneWidget);
      expect(find.byKey(const Key('nav-group-movies')), findsOneWidget);
      expect(find.byKey(const Key('nav-group-actors')), findsOneWidget);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });
}

Future<void> _pumpSidebar(
  WidgetTester tester, {
  required String currentPath,
  TargetPlatform platform = TargetPlatform.linux,
}) async {
  debugDefaultTargetPlatformOverride = platform;
  await pumpWithProviders(
    tester,
    home: Scaffold(
      body: Row(
        children: <Widget>[
          AppSidebar(currentPath: currentPath, navItems: _navItems),
          const Expanded(child: SizedBox.shrink()),
        ],
      ),
    ),
    physicalSize: const Size(900, 700),
    theme: sakuraDesktopThemeData,
    overrides: <Override>[
      pluginsProvider.overrideWith(_EmptyPlugins.new),
      appUpdateCheckProvider.overrideWith(_NoUpdates.new),
    ],
  );
  await tester.pump();
}

bool _isSelected(WidgetTester tester, String groupId) {
  return tester
      .widget<AppSidebarItem>(find.byKey(Key('nav-group-$groupId')))
      .selected;
}

const List<AppNavItem> _navItems = <AppNavItem>[
  AppNavItem(
    routeId: AppRouteId.desktopMovies,
    name: 'movies',
    label: 'Movies',
    path: '/desktop/library/movies',
    icon: Icons.movie_outlined,
    description: 'Browse movies',
    sectionLabel: 'Browse',
  ),
  AppNavItem(
    routeId: AppRouteId.desktopActors,
    name: 'actors',
    label: 'Actors',
    path: '/desktop/library/actors',
    icon: Icons.people_outline_rounded,
    description: 'Browse actors',
    sectionLabel: 'Browse',
  ),
];

final List<AppNavItem> _manyNavItems = List<AppNavItem>.generate(
  20,
  (index) => AppNavItem(
    routeId: AppRouteId.desktopMovies,
    name: 'group-$index',
    label: 'Group $index',
    path: '/desktop/library/group-$index',
    icon: Icons.movie_outlined,
    description: 'Group $index',
    sectionLabel: 'Browse',
  ),
);

class _CollapsedSidebar extends AppShellSidebarCollapsed {
  @override
  bool build() => true;
}

class _EmptyPlugins extends Plugins {
  @override
  Future<PluginsState> build() async => const PluginsState(plugins: []);
}

class _NoUpdates extends AppUpdateCheck {
  @override
  AppUpdateCheckState build() => AppUpdateCheckState.initial;
}
