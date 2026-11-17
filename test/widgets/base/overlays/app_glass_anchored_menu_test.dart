import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/interaction/app_interactive_surface.dart';
import 'package:sakuramedia/widgets/base/layout/surface/app_surface.dart';
import 'package:sakuramedia/widgets/base/overlays/app_glass_anchored_menu.dart';

import '../../../support/pump_with_providers.dart';

void main() {
  testWidgets('opens, selects and closes on outside tap', (tester) async {
    var selected = 0;
    await _pumpMenu(
      tester,
      contentBuilder: (context, close) => Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          AppGlassMenuRow(
            key: const Key('menu-row-1'),
            title: const Text('选项一'),
            onTap: () {
              selected = 1;
              close();
            },
          ),
        ],
      ),
    );

    await tester.tap(find.byKey(const Key('menu-trigger')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('menu-panel')), findsOneWidget);

    await tester.tap(find.byKey(const Key('menu-row-1')));
    await tester.pumpAndSettle();
    expect(selected, 1);
    expect(find.byKey(const Key('menu-panel')), findsNothing);

    await tester.tap(find.byKey(const Key('menu-trigger')));
    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(1, 1));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('menu-panel')), findsNothing);
  });

  testWidgets('escape closes the menu', (tester) async {
    await _pumpMenu(
      tester,
      contentBuilder: (context, close) =>
          const AppGlassMenuRow(title: Text('选项一')),
    );

    await tester.tap(find.byKey(const Key('menu-trigger')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('menu-panel')), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('menu-panel')), findsNothing);
  });

  testWidgets('opens upward when the trigger is near the bottom', (
    tester,
  ) async {
    await _pumpMenu(
      tester,
      alignment: Alignment.bottomCenter,
      contentBuilder: (context, close) => SizedBox(
        height: 180,
        child: Column(
          children: <Widget>[
            const AppGlassMenuRow(title: Text('选项一')),
            for (var index = 0; index < 4; index++)
              const AppGlassMenuRow(title: Text('选项')),
          ],
        ),
      ),
      size: const Size(400, 600),
    );

    await tester.tap(find.byKey(const Key('menu-trigger')));
    await tester.pumpAndSettle();

    final triggerRect = tester.getRect(find.byKey(const Key('menu-trigger')));
    final panelRect = tester.getRect(find.byKey(const Key('menu-panel')));
    expect(panelRect.top, lessThan(triggerRect.top));
  });

  testWidgets('long content scrolls inside the panel', (tester) async {
    await _pumpMenu(
      tester,
      maxHeight: 160,
      contentBuilder: (context, close) => Column(
        children: <Widget>[
          for (var index = 0; index < 20; index++)
            AppGlassMenuRow(title: Text('选项 $index')),
        ],
      ),
    );

    await tester.tap(find.byKey(const Key('menu-trigger')));
    await tester.pumpAndSettle();

    final scrollable = tester.state<ScrollableState>(
      find.descendant(
        of: find.byKey(const Key('menu-panel')),
        matching: find.byType(Scrollable),
      ),
    );
    expect(scrollable.position.maxScrollExtent, greaterThan(0));
    await tester.drag(
      find.byKey(const Key('menu-scroll')),
      const Offset(0, -120),
    );
    await tester.pumpAndSettle();
    expect(scrollable.position.pixels, greaterThan(0));
  });

  testWidgets('flat mode keeps menu selection behavior', (tester) async {
    var tapped = false;
    await _pumpMenu(
      tester,
      flat: true,
      contentBuilder: (context, close) => AppGlassMenuRow(
        key: const Key('flat-menu-row'),
        title: const Text('扁平选项'),
        onTap: () {
          tapped = true;
          close();
        },
      ),
    );

    await tester.tap(find.byKey(const Key('menu-trigger')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('flat-menu-row')));
    await tester.pumpAndSettle();
    expect(tapped, isTrue);
    expect(find.byKey(const Key('menu-panel')), findsNothing);
  });
}

Future<void> _pumpMenu(
  WidgetTester tester, {
  required AppGlassAnchoredMenuContentBuilder contentBuilder,
  Alignment alignment = Alignment.center,
  Size size = const Size(800, 600),
  double? maxHeight,
  bool flat = false,
}) async {
  await pumpWithProviders(
    tester,
    physicalSize: size,
    theme: sakuraDesktopThemeData,
    wrap: flat
        ? (child) =>
              AppSurfaceStyleScope(style: AppSurfaceStyle.flat, child: child)
        : null,
    home: Scaffold(
      body: Align(
        alignment: alignment,
        child: SizedBox(
          width: 300,
          child: AppGlassAnchoredMenu(
            width: 240,
            estimatedHeight: 240,
            maxHeight: maxHeight,
            panelKey: const Key('menu-panel'),
            scrollViewKey: const Key('menu-scroll'),
            triggerBuilder: (context, isOpen, toggle) => AppInteractiveSurface(
              key: const Key('menu-trigger'),
              onTap: toggle,
              child: const Padding(
                padding: EdgeInsets.all(12),
                child: Text('打开菜单'),
              ),
            ),
            contentBuilder: contentBuilder,
          ),
        ),
      ),
    ),
  );
}
