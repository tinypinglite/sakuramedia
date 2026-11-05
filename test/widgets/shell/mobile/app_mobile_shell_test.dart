import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:sakuramedia/routes/app_route_spec.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/shell/mobile/app_mobile_shell.dart';

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
          child: SizedBox(key: Key('mobile-shell-child')),
        ),
      ),
    );

    final tabBar = tester.widget<CupertinoTabBar>(find.byType(CupertinoTabBar));
    final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
    final shellPadding = tester.widget<Padding>(
      find.byKey(const Key('mobile-shell-body-padding')),
    );
    final bodySafeArea = tester.widget<SafeArea>(
      find.byKey(const Key('mobile-shell-body-safe-area')),
    );
    final bottomSafeArea = tester.widget<SafeArea>(
      find.byKey(const Key('mobile-shell-bottom-safe-area')),
    );

    expect(tabBar.currentIndex, 1);
    expect(tabBar.height, 52);
    expect(scaffold.backgroundColor, sakuraThemeData.appColors.surfaceCard);
    expect(scaffold.drawer, isNull);
    expect(scaffold.drawerEnableOpenDragGesture, isFalse);
    expect(shellPadding.padding, AppPageInsets.compactStandard);
    expect(bodySafeArea.bottom, isFalse);
    expect(bottomSafeArea.top, isFalse);
    expect(find.byType(AnnotatedRegion<SystemUiOverlayStyle>), findsOneWidget);
    expect(find.byType(AppBar), findsNothing);
  });

  testWidgets(
    'mobile shell keeps overview tab selected on nested overview path',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: sakuraThemeData,
          home: const AppMobileShell(
            currentPath: '/mobile/overview/playlists/8',
            navGroups: navGroups,
            child: SizedBox.shrink(),
          ),
        ),
      );

      final tabBar = tester.widget<CupertinoTabBar>(
        find.byType(CupertinoTabBar),
      );
      expect(tabBar.currentIndex, 0);
    },
  );

  testWidgets('mobile shell supports optional drawer without affecting tabs', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: sakuraThemeData,
        home: const AppMobileShell(
          currentPath: '/mobile/overview',
          navGroups: navGroups,
          drawer: Drawer(child: Text('drawer-content')),
          drawerEnableOpenDragGesture: true,
          child: SizedBox.shrink(),
        ),
      ),
    );

    final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
    final tabBar = tester.widget<CupertinoTabBar>(find.byType(CupertinoTabBar));

    expect(scaffold.drawer, isNotNull);
    expect(scaffold.drawerEnableOpenDragGesture, isTrue);
    expect(tabBar.currentIndex, 0);
  });

  // Flutter 默认的 20dp 边缘拖拽区整条落在 Android 手势导航的返回手势区里、
  // 被系统优先消费,所以拖拽区必须从 systemGestureInsets 往内侧起算。
  testWidgets('mobile shell edge drag width clears the system gesture inset', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: sakuraThemeData,
        home: const MediaQuery(
          data: MediaQueryData(systemGestureInsets: EdgeInsets.only(left: 32)),
          child: AppMobileShell(
            currentPath: '/mobile/overview',
            navGroups: navGroups,
            drawer: Drawer(child: Text('drawer-content')),
            drawerEnableOpenDragGesture: true,
            child: SizedBox.shrink(),
          ),
        ),
      ),
    );

    final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
    expect(scaffold.drawerEdgeDragWidth, 32 + sakuraThemeData.appSpacing.xl);
  });

  testWidgets('mobile shell leaves edge drag width unset when drag is off', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: sakuraThemeData,
        home: const MediaQuery(
          data: MediaQueryData(systemGestureInsets: EdgeInsets.only(left: 32)),
          child: AppMobileShell(
            currentPath: '/mobile/overview',
            navGroups: navGroups,
            drawer: Drawer(child: Text('drawer-content')),
            child: SizedBox.shrink(),
          ),
        ),
      ),
    );

    final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
    expect(scaffold.drawerEnableOpenDragGesture, isFalse);
    expect(scaffold.drawerEdgeDragWidth, isNull);
  });

  testWidgets('mobile shell navigates when tapping bottom destination', (
    tester,
  ) async {
    final router = GoRouter(
      initialLocation: '/mobile/overview',
      routes: [
        ShellRoute(
          builder: (context, state, child) => AppMobileShell(
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

  testWidgets('mobile shell pulses the active icon only when switching tabs', (
    tester,
  ) async {
    await tester.pumpWidget(_ShellHarness(navGroups: navGroups));
    await tester.pumpAndSettle();

    const pulseKey = Key('mobile-nav-active-icon-pulse');
    // 首屏当前 tab 不做动效。
    expect(find.byKey(pulseKey), findsNothing);

    await tester.tap(find.text('影片'));
    await tester.pump();
    expect(find.byKey(pulseKey), findsOneWidget);

    // 动效前半段先缩小（缩放 < 1.0）。
    await tester.pump(const Duration(milliseconds: 40));
    final shrinking = tester.widget<Transform>(
      find
          .descendant(
            of: find.byKey(pulseKey),
            matching: find.byType(Transform),
          )
          .first,
    );
    expect(shrinking.transform.entry(0, 0), lessThan(1.0));

    await tester.pumpAndSettle();
    final settled = tester.widget<Transform>(
      find
          .descendant(
            of: find.byKey(pulseKey),
            matching: find.byType(Transform),
          )
          .first,
    );
    expect(
      settled.transform.entry(0, 0),
      moreOrLessEquals(1.0, epsilon: 0.001),
    );
  });

  testWidgets(
    'mobile shell skips the icon pulse when animations are disabled',
    (tester) async {
      await tester.pumpWidget(
        _ShellHarness(navGroups: navGroups, disableAnimations: true),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('影片'));
      await tester.pump();
      expect(
        find.byKey(const Key('mobile-nav-active-icon-pulse')),
        findsNothing,
      );
    },
  );

  testWidgets('mobile shell fires selection haptic only on tab change', (
    tester,
  ) async {
    final calls = <MethodCall>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        calls.add(call);
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );

    await tester.pumpWidget(_ShellHarness(navGroups: navGroups));
    await tester.pumpAndSettle();

    await tester.tap(find.text('影片'));
    await tester.pumpAndSettle();
    expect(
      calls.map((call) => '${call.method}:${call.arguments}'),
      contains('HapticFeedback.vibrate:HapticFeedbackType.selectionClick'),
    );

    calls.clear();
    // 重复点当前 tab 不再触发触感。
    await tester.tap(find.text('影片'));
    await tester.pumpAndSettle();
    expect(
      calls.where((call) => call.method == 'HapticFeedback.vibrate'),
      isEmpty,
    );
  });

  testWidgets('mobile shell uses the filled activeIcon for the selected tab', (
    tester,
  ) async {
    const groups = [
      AppNavGroup(
        id: 'overview',
        label: '概览',
        icon: Icons.pix_outlined,
        isCollapsible: false,
        items: [
          AppNavItem(
            name: 'mobile-overview',
            label: '概览',
            path: '/mobile/overview',
            icon: Icons.pix_outlined,
            activeIcon: Icons.pix,
            description: 'overview',
          ),
        ],
      ),
      AppNavGroup(
        id: 'movies',
        label: '影片',
        icon: Icons.movie_outlined,
        isCollapsible: false,
        items: [
          AppNavItem(
            name: 'mobile-library/movies',
            label: '影片',
            path: '/mobile/library/movies',
            icon: Icons.movie_outlined,
            activeIcon: Icons.movie,
            description: 'movies',
          ),
        ],
      ),
    ];

    await tester.pumpWidget(_ShellHarness(navGroups: groups));
    await tester.pumpAndSettle();

    CupertinoTabBar bar() =>
        tester.widget<CupertinoTabBar>(find.byType(CupertinoTabBar));
    Icon iconOf(Widget w) => w as Icon;

    // 未选中一律用线框图标，选中用实心 activeIcon。
    expect(iconOf(bar().items[0].icon).icon, Icons.pix_outlined);
    expect(iconOf(bar().items[1].icon).icon, Icons.movie_outlined);
    expect(iconOf(bar().items[0].activeIcon!).icon, Icons.pix);
    expect(iconOf(bar().items[1].activeIcon!).icon, Icons.movie);

    await tester.tap(find.text('影片'));
    await tester.pumpAndSettle();
    expect(bar().currentIndex, 1);
  });
}

/// 用可变下标驱动 [AppMobileShell]，模拟真实路由切换 tab 的场景。
class _ShellHarness extends StatefulWidget {
  const _ShellHarness({
    required this.navGroups,
    this.disableAnimations = false,
  });

  final List<AppNavGroup> navGroups;
  final bool disableAnimations;

  @override
  State<_ShellHarness> createState() => _ShellHarnessState();
}

class _ShellHarnessState extends State<_ShellHarness> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final items = widget.navGroups
        .expand((group) => group.items)
        .toList(growable: false);
    return MaterialApp(
      theme: sakuraThemeData,
      home: Builder(
        builder: (context) {
          Widget shell = AppMobileShell(
            currentPath: items[_index].path,
            navGroups: widget.navGroups,
            currentIndex: _index,
            onDestinationSelected: (index) => setState(() => _index = index),
            child: const SizedBox.shrink(),
          );
          if (widget.disableAnimations) {
            shell = MediaQuery(
              data: MediaQuery.of(context).copyWith(disableAnimations: true),
              child: shell,
            );
          }
          return shell;
        },
      ),
    );
  }
}
