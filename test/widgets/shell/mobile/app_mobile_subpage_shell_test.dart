import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/shell/mobile/app_mobile_subpage_shell.dart';

void main() {
  testWidgets('renders the standard subpage chrome', (tester) async {
    await _pumpShell(
      tester,
      title: 'Subpage title',
      child: const SizedBox.expand(),
    );

    expect(find.byKey(const Key('mobile-subpage-topbar')), findsOneWidget);
    expect(find.byKey(const Key('mobile-subpage-back-button')), findsOneWidget);
    expect(find.byKey(const Key('mobile-subpage-title')), findsOneWidget);
    expect(find.byKey(const Key('mobile-subpage-safe-area')), findsOneWidget);
    expect(
      find.byKey(const Key('mobile-subpage-system-overlay')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('mobile-subpage-root-surface')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('mobile-subpage-body-padding')),
      findsOneWidget,
    );
    expect(find.text('Subpage title'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('title override updates and clears the app bar title', (
    tester,
  ) async {
    ValueNotifier<String?>? title;
    await _pumpShell(
      tester,
      title: 'Static title',
      child: Builder(
        builder: (context) {
          title = AppMobileSubpageTitle.read(context);
          return const SizedBox.expand();
        },
      ),
    );

    expect(title, isNotNull);
    title!.value = 'Loaded title';
    await tester.pump();
    expect(find.text('Loaded title'), findsOneWidget);

    title!.value = '   ';
    await tester.pump();
    expect(find.text('Static title'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('glass chrome stays mounted when auto-hide is requested', (
    tester,
  ) async {
    final controller = ScrollController();
    addTearDown(controller.dispose);
    await _pumpShell(
      tester,
      glassChrome: true,
      autoHideAppBar: true,
      child: _longList(controller),
    );

    final topBar = find.byKey(const Key('mobile-subpage-topbar'));
    expect(topBar, findsOneWidget);
    expect(find.byKey(const Key('mobile-subpage-title')), findsOneWidget);
    expect(find.byKey(const Key('mobile-subpage-back-button')), findsOneWidget);

    controller.jumpTo(200);
    await tester.pumpAndSettle();
    expect(topBar, findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('immersive chrome keeps the overlay app bar without a title', (
    tester,
  ) async {
    final controller = ScrollController();
    addTearDown(controller.dispose);
    await _pumpShell(
      tester,
      immersive: true,
      autoHideAppBar: true,
      child: _longList(controller),
    );

    final topBar = find.byKey(const Key('mobile-subpage-topbar'));
    expect(topBar, findsOneWidget);
    expect(find.byKey(const Key('mobile-subpage-title')), findsNothing);
    expect(find.byKey(const Key('mobile-subpage-back-button')), findsOneWidget);

    controller.jumpTo(200);
    await tester.pumpAndSettle();
    expect(topBar, findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('auto-hide collapses away from top and restores at top', (
    tester,
  ) async {
    final controller = ScrollController();
    addTearDown(controller.dispose);
    await _pumpShell(
      tester,
      autoHideAppBar: true,
      child: _longList(controller),
    );

    final topBar = find.byKey(const Key('mobile-subpage-topbar'));
    expect(topBar, findsOneWidget);

    controller.jumpTo(200);
    await tester.pumpAndSettle();
    expect(topBar, findsNothing);

    controller.jumpTo(120);
    await tester.pumpAndSettle();
    expect(topBar, findsNothing);

    controller.jumpTo(0);
    await tester.pumpAndSettle();
    expect(topBar, findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('vertical lists inside a PageView also drive auto-hide', (
    tester,
  ) async {
    final controller = ScrollController();
    addTearDown(controller.dispose);
    await _pumpShell(
      tester,
      autoHideAppBar: true,
      child: PageView(
        children: [
          _longList(controller, key: const Key('subpage-page-view-list')),
        ],
      ),
    );

    final topBar = find.byKey(const Key('mobile-subpage-topbar'));
    expect(topBar, findsOneWidget);

    controller.jumpTo(200);
    await tester.pumpAndSettle();
    expect(topBar, findsNothing);

    controller.jumpTo(0);
    await tester.pumpAndSettle();
    expect(topBar, findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('switching TabBarView tabs restores the auto-hidden app bar', (
    tester,
  ) async {
    final controller = ScrollController();
    addTearDown(controller.dispose);
    await _pumpShell(
      tester,
      autoHideAppBar: true,
      child: DefaultTabController(
        length: 2,
        child: Column(
          children: [
            const TabBar(
              tabs: [
                Tab(text: 'A'),
                Tab(text: 'B'),
              ],
            ),
            Expanded(
              child: TabBarView(
                children: [
                  _longList(controller, key: const Key('subpage-tab-a-list')),
                  const Center(child: Text('empty-b')),
                ],
              ),
            ),
          ],
        ),
      ),
    );

    final topBar = find.byKey(const Key('mobile-subpage-topbar'));
    controller.jumpTo(300);
    await tester.pumpAndSettle();
    expect(topBar, findsNothing);

    await tester.tap(find.text('B'));
    await tester.pumpAndSettle();
    expect(topBar, findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('back button pops an existing route stack', (tester) async {
    final router = _buildRouter(initialLocation: '/home');
    addTearDown(router.dispose);
    await _pumpRouter(tester, router);

    await tester.tap(find.text('open-sub'));
    await tester.pumpAndSettle();
    expect(_currentPath(router), '/sub');

    await tester.tap(find.byKey(const Key('mobile-subpage-back-button')));
    await tester.pumpAndSettle();
    expect(_currentPath(router), '/home');
    expect(tester.takeException(), isNull);
  });

  testWidgets('system back pops an existing route stack', (tester) async {
    final router = _buildRouter(initialLocation: '/home');
    addTearDown(router.dispose);
    await _pumpRouter(tester, router);

    await tester.tap(find.text('open-sub'));
    await tester.pumpAndSettle();
    expect(_currentPath(router), '/sub');

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(_currentPath(router), '/home');
    expect(tester.takeException(), isNull);
  });

  testWidgets('deep-link back uses defaultLocation', (tester) async {
    final router = _buildRouter(initialLocation: '/sub');
    addTearDown(router.dispose);
    await _pumpRouter(tester, router);

    await tester.tap(find.byKey(const Key('mobile-subpage-back-button')));
    await tester.pumpAndSettle();
    expect(_currentPath(router), '/home');
    expect(tester.takeException(), isNull);
  });

  testWidgets('deep-link back prefers fallbackPath over defaultLocation', (
    tester,
  ) async {
    final router = _buildRouter(
      initialLocation: '/sub',
      fallbackPath: '/fallback',
    );
    addTearDown(router.dispose);
    await _pumpRouter(tester, router);

    await tester.tap(find.byKey(const Key('mobile-subpage-back-button')));
    await tester.pumpAndSettle();
    expect(_currentPath(router), '/fallback');
    expect(tester.takeException(), isNull);
  });

  testWidgets('back interceptor can block and then allow a pop', (
    tester,
  ) async {
    AppMobileSubpageBackInterceptorController? interceptor;
    final router = _buildRouter(
      initialLocation: '/home',
      onInterceptor: (controller) => interceptor = controller,
    );
    addTearDown(router.dispose);
    await _pumpRouter(tester, router);

    await tester.tap(find.text('open-sub'));
    await tester.pumpAndSettle();
    expect(interceptor, isNotNull);

    var calls = 0;
    var allowPop = false;
    Future<bool> handler() async {
      calls++;
      return allowPop;
    }

    interceptor!.attach(handler);
    interceptor!.setCanPop(false);
    await tester.tap(find.byKey(const Key('mobile-subpage-back-button')));
    await tester.pumpAndSettle();
    expect(calls, 1);
    expect(_currentPath(router), '/sub');

    allowPop = true;
    interceptor!.setCanPop(true);
    await tester.tap(find.byKey(const Key('mobile-subpage-back-button')));
    await tester.pumpAndSettle();
    expect(calls, 2);
    expect(_currentPath(router), '/home');
    expect(tester.takeException(), isNull);
  });

  test('back interceptor controller detaches and resets canPop', () async {
    final controller = AppMobileSubpageBackInterceptorController();
    addTearDown(controller.dispose);
    Future<bool> handler() async => false;

    expect(controller.canPop.value, isTrue);
    expect(await controller.shouldPop(), isTrue);

    controller.setCanPop(false);
    expect(controller.canPop.value, isTrue);

    controller.attach(handler);
    controller.setCanPop(false);
    expect(controller.canPop.value, isFalse);
    expect(await controller.shouldPop(), isFalse);

    controller.detach(handler);
    expect(controller.canPop.value, isTrue);
    expect(await controller.shouldPop(), isTrue);
  });
}

Widget _longList(
  ScrollController controller, {
  Key key = const Key('subpage-scroll'),
}) {
  return ListView.builder(
    key: key,
    controller: controller,
    itemCount: 60,
    itemBuilder: (_, _) => const SizedBox(height: 40),
  );
}

Future<void> _pumpShell(
  WidgetTester tester, {
  required Widget child,
  String title = 'Subpage',
  String defaultLocation = '/home',
  bool immersive = false,
  bool autoHideAppBar = false,
  bool glassChrome = false,
}) {
  return _pump(
    tester,
    MaterialApp(
      theme: sakuraMobileThemeData,
      home: AppMobileSubpageShell(
        title: title,
        defaultLocation: defaultLocation,
        immersive: immersive,
        autoHideAppBar: autoHideAppBar,
        glassChrome: glassChrome,
        child: child,
      ),
    ),
  );
}

GoRouter _buildRouter({
  required String initialLocation,
  String? fallbackPath,
  ValueChanged<AppMobileSubpageBackInterceptorController?>? onInterceptor,
}) {
  return GoRouter(
    initialLocation: initialLocation,
    routes: [
      GoRoute(
        path: '/home',
        builder: (context, state) => Scaffold(
          body: Center(
            child: TextButton(
              onPressed: () => context.push('/sub'),
              child: const Text('open-sub'),
            ),
          ),
        ),
      ),
      GoRoute(
        path: '/fallback',
        builder: (context, state) =>
            const Scaffold(body: Text('fallback-page')),
      ),
      GoRoute(
        path: '/sub',
        builder: (context, state) => AppMobileSubpageShell(
          title: 'Subpage',
          defaultLocation: '/home',
          fallbackPath: fallbackPath,
          child: onInterceptor == null
              ? const SizedBox.expand()
              : Builder(
                  builder: (context) {
                    onInterceptor(
                      AppMobileSubpageBackInterceptor.maybeOf(context),
                    );
                    return const SizedBox.expand();
                  },
                ),
        ),
      ),
    ],
  );
}

Future<void> _pumpRouter(WidgetTester tester, GoRouter router) {
  return _pump(
    tester,
    MaterialApp.router(theme: sakuraMobileThemeData, routerConfig: router),
  );
}

String _currentPath(GoRouter router) =>
    router.routerDelegate.currentConfiguration.last.matchedLocation;

Future<void> _pump(WidgetTester tester, Widget app) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(390, 844);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);

  await tester.pumpWidget(
    LiquidGlassWidgets.wrap(
      brightnessResolver: Theme.maybeBrightnessOf,
      child: app,
    ),
  );
  await tester.pumpAndSettle();
}
