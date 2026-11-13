import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:multi_split_view/multi_split_view.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/domain/media/collapsible_player_split_view.dart';

import '../../../support/pump_with_providers.dart';

void main() {
  testWidgets('右上角开关可收起并重新展开面板', (tester) async {
    final controller = MultiSplitViewController(
      areas: <Area>[Area(flex: 0.72), Area(flex: 0.28)],
    );
    addTearDown(controller.dispose);

    await pumpWithProviders(
      tester,
      theme: buildSakuraMobileThemeData(),
      physicalSize: const Size(1200, 675),
      home: CollapsiblePlayerSplitView(
        controller: controller,
        collapsible: true,
        handleKey: const Key('panel-handle'),
        leftBuilder: (context) => const SizedBox.expand(key: Key('left-panel')),
        rightBuilder: (context) =>
            const SizedBox.expand(key: Key('right-panel')),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('right-panel')), findsOneWidget);
    expect(controller.areas[1].flex, closeTo(0.28, 0.001));

    await tester.tap(find.byKey(const Key('panel-handle')));
    await tester.pumpAndSettle();

    expect(controller.areas[1].flex, closeTo(0, 0.0001));
    expect(find.byKey(const Key('right-panel')), findsNothing);

    await tester.tap(find.byKey(const Key('panel-handle')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('right-panel')), findsOneWidget);
    expect(controller.areas[1].flex, greaterThan(0));
  });

  testWidgets('横屏转竖屏自动收起面板，开关仍可手动展开', (tester) async {
    final controller = MultiSplitViewController(
      areas: <Area>[Area(flex: 0.72), Area(flex: 0.28)],
    );
    addTearDown(controller.dispose);

    await pumpWithProviders(
      tester,
      theme: buildSakuraMobileThemeData(),
      physicalSize: const Size(844, 390),
      home: CollapsiblePlayerSplitView(
        controller: controller,
        collapsible: true,
        collapseWhenPortrait: true,
        handleKey: const Key('panel-handle'),
        leftBuilder: (context) => const SizedBox.expand(key: Key('left-panel')),
        rightBuilder: (context) =>
            const SizedBox.expand(key: Key('right-panel')),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('right-panel')), findsOneWidget);
    expect(controller.areas[1].flex, closeTo(0.28, 0.001));

    tester.view.physicalSize = const Size(390, 844);
    await tester.pumpAndSettle();

    expect(controller.areas[1].flex, closeTo(0, 0.0001));
    expect(find.byKey(const Key('right-panel')), findsNothing);
    expect(find.byKey(const Key('panel-handle')), findsOneWidget);

    await tester.tap(find.byKey(const Key('panel-handle')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('right-panel')), findsOneWidget);
    expect(controller.areas[1].flex, greaterThan(0));
  });

  testWidgets('未开启 collapseWhenPortrait 时竖屏不收起面板', (tester) async {
    final controller = MultiSplitViewController(
      areas: <Area>[Area(flex: 0.72), Area(flex: 0.28)],
    );
    addTearDown(controller.dispose);

    await pumpWithProviders(
      tester,
      theme: buildSakuraMobileThemeData(),
      physicalSize: const Size(844, 390),
      home: CollapsiblePlayerSplitView(
        controller: controller,
        collapsible: true,
        handleKey: const Key('panel-handle'),
        leftBuilder: (context) => const SizedBox.expand(key: Key('left-panel')),
        rightBuilder: (context) =>
            const SizedBox.expand(key: Key('right-panel')),
      ),
    );
    await tester.pumpAndSettle();

    tester.view.physicalSize = const Size(390, 844);
    await tester.pumpAndSettle();

    expect(controller.areas[1].flex, closeTo(0.28, 0.001));
    expect(find.byKey(const Key('right-panel')), findsOneWidget);
  });
}
