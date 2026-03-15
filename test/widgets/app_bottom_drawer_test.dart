import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/app_bottom_drawer.dart';

void main() {
  testWidgets('app bottom drawer uses custom slim handle by default', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: sakuraThemeData,
        home: Builder(
          builder:
              (context) => Scaffold(
                body: TextButton(
                  onPressed: () {
                    showAppBottomDrawer<void>(
                      context: context,
                      builder:
                          (_) => const SizedBox(
                            key: Key('app-bottom-drawer-probe'),
                            width: 24,
                            height: 24,
                          ),
                    );
                  },
                  child: const Text('open'),
                ),
              ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    final handleFinder = find.byKey(const Key('app-bottom-drawer-handle'));
    expect(handleFinder, findsOneWidget);
    expect(tester.getSize(handleFinder), const Size(28, 3));
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget.runtimeType.toString().contains('BottomSheetDragHandle'),
      ),
      findsNothing,
    );
  });

  testWidgets('app bottom drawer applies default content padding', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: sakuraThemeData,
        home: Builder(
          builder:
              (context) => Scaffold(
                body: TextButton(
                  onPressed: () {
                    showAppBottomDrawer<void>(
                      context: context,
                      builder:
                          (_) => const Align(
                            alignment: Alignment.topLeft,
                            child: SizedBox(
                              key: Key('app-bottom-drawer-padding-probe'),
                              width: 12,
                              height: 12,
                            ),
                          ),
                    );
                  },
                  child: const Text('open'),
                ),
              ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    final contentTopLeft = tester.getTopLeft(
      find.byKey(const Key('app-bottom-drawer-content')),
    );
    final probeTopLeft = tester.getTopLeft(
      find.byKey(const Key('app-bottom-drawer-padding-probe')),
    );

    expect(probeTopLeft.dx - contentTopLeft.dx, 16);
    expect(probeTopLeft.dy - contentTopLeft.dy, 16);
  });
}
