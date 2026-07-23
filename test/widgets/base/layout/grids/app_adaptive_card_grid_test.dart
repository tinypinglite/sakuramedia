import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/layout/grids/app_adaptive_card_grid.dart';

void main() {
  testWidgets('AppAdaptiveCardSliver virtualizes accumulated grid items', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(900, 500);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final items = List<int>.generate(200, (index) => index);
    await tester.pumpWidget(
      MaterialApp(
        theme: sakuraThemeData,
        home: Scaffold(
          body: CustomScrollView(
            key: const Key('adaptive-grid-scroll-view'),
            slivers: [
              AppAdaptiveCardSliver<int>(
                gridKey: const Key('adaptive-card-sliver'),
                items: items,
                isLoading: false,
                minColumns: 4,
                maxColumns: 4,
                childAspectRatio: 1,
                skeletonBuilder: (context, index) => const SizedBox.shrink(),
                itemBuilder:
                    (context, item, index) => SizedBox(
                      key: Key('adaptive-grid-item-$item'),
                      child: Text('$item'),
                    ),
              ),
            ],
          ),
        ),
      ),
    );

    expect(find.byKey(const Key('adaptive-card-sliver')), findsOneWidget);
    expect(find.byKey(const Key('adaptive-grid-item-0')), findsOneWidget);
    expect(find.byKey(const Key('adaptive-grid-item-199')), findsNothing);

    await tester.scrollUntilVisible(
      find.byKey(const Key('adaptive-grid-item-199')),
      900,
      scrollable: find.descendant(
        of: find.byKey(const Key('adaptive-grid-scroll-view')),
        matching: find.byType(Scrollable),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('adaptive-grid-item-199')), findsOneWidget);
    expect(find.byKey(const Key('adaptive-grid-item-0')), findsNothing);
  });
}
