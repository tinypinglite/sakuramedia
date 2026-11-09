import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:multi_split_view/multi_split_view.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/domain/media/collapsible_player_split_view.dart';

import '../../../support/pump_with_providers.dart';

void main() {
  testWidgets('旋转请求收起面板后可用右上角开关重新展开', (tester) async {
    final controller = MultiSplitViewController(
      areas: <Area>[Area(flex: 0.72), Area(flex: 0.28)],
    );
    addTearDown(controller.dispose);
    var collapseRequest = 0;
    late StateSetter updateState;

    await pumpWithProviders(
      tester,
      theme: buildSakuraMobileThemeData(),
      physicalSize: const Size(1200, 675),
      home: StatefulBuilder(
        builder: (context, setState) {
          updateState = setState;
          return CollapsiblePlayerSplitView(
            controller: controller,
            collapsible: true,
            handleKey: const Key('panel-handle'),
            collapseRequest: collapseRequest,
            leftBuilder: (context) =>
                const SizedBox.expand(key: Key('left-panel')),
            rightBuilder: (context) =>
                const SizedBox.expand(key: Key('right-panel')),
          );
        },
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('right-panel')), findsOneWidget);
    expect(controller.areas[1].flex, closeTo(0.28, 0.001));

    updateState(() => collapseRequest++);
    await tester.pumpAndSettle();

    expect(controller.areas[1].flex, closeTo(0, 0.0001));
    expect(find.byKey(const Key('right-panel')), findsNothing);

    await tester.tap(find.byKey(const Key('panel-handle')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('right-panel')), findsOneWidget);
    expect(controller.areas[1].flex, greaterThan(0));
  });
}
