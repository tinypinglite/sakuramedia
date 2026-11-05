import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/app/app_tooltip_navigator_observer.dart';

void main() {
  testWidgets('dismisses an open tooltip before an obstructed route resizes', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(800, 600);
    addTearDown(tester.view.reset);

    final navigatorKey = GlobalKey<NavigatorState>();
    final tooltipKey = GlobalKey<TooltipState>();
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navigatorKey,
        navigatorObservers: <NavigatorObserver>[AppTooltipNavigatorObserver()],
        home: Scaffold(
          body: Center(
            child: Tooltip(
              key: tooltipKey,
              message: '演员名',
              child: const SizedBox(
                width: 100,
                height: 100,
                child: ColoredBox(color: Colors.blue),
              ),
            ),
          ),
        ),
      ),
    );

    expect(tooltipKey.currentState!.ensureTooltipVisible(), isTrue);
    await tester.pumpAndSettle();
    expect(find.text('演员名'), findsOneWidget);

    navigatorKey.currentState!.push<void>(
      MaterialPageRoute<void>(
        builder: (_) => const Scaffold(body: SizedBox.expand()),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    tester.view.physicalSize = const Size(1000, 700);
    await tester.pump();

    expect(tester.takeException(), isNull);
  });
}
