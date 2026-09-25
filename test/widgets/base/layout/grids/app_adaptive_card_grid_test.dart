import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/layout/grids/app_adaptive_card_grid.dart';
import 'package:sakuramedia/widgets/base/layout/grids/grid_column_resolver.dart';

void main() {
  testWidgets('AppAdaptiveCardGrid limits preview content to configured rows', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    Future<void> pumpGrid(double width) {
      return tester.pumpWidget(
        MaterialApp(
          theme: sakuraThemeData,
          home: Scaffold(
            body: Align(
              alignment: Alignment.topLeft,
              child: SizedBox(
                width: width,
                height: 400,
                child: AppAdaptiveCardGrid<int>(
                  gridKey: const Key('single-row-adaptive-grid'),
                  items: List<int>.generate(8, (index) => index),
                  targetColumnWidth: 280,
                  maxColumns: 4,
                  maxRows: 2,
                  childAspectRatio: 2,
                  itemBuilder: (_, item, __) =>
                      SizedBox(key: Key('single-row-adaptive-grid-item-$item')),
                ),
              ),
            ),
          ),
        ),
      );
    }

    // 与 1280px 默认窗口、展开侧栏后的发现页内容宽度一致：只能排 3 列。
    await pumpGrid(1012);
    var grid = tester.widget<GridView>(
      find.byKey(const Key('single-row-adaptive-grid')),
    );
    var delegate = grid.childrenDelegate as SliverChildBuilderDelegate;
    expect(delegate.childCount, 6);
    expect(
      find.byKey(const Key('single-row-adaptive-grid-item-6')),
      findsNothing,
    );

    await pumpGrid(1200);
    grid = tester.widget<GridView>(
      find.byKey(const Key('single-row-adaptive-grid')),
    );
    delegate = grid.childrenDelegate as SliverChildBuilderDelegate;
    expect(delegate.childCount, 8);
    expect(
      find.byKey(const Key('single-row-adaptive-grid-item-6')),
      findsOneWidget,
    );
  });

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
                minColumns: 4,
                maxColumns: 4,
                childAspectRatio: 1,
                itemBuilder: (context, item, index) => SizedBox(
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

  testWidgets('AppAdaptiveCardGrid defaults to the unified card grid spec', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(2400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        theme: sakuraThemeData,
        home: Scaffold(
          body: AppAdaptiveCardGrid<int>(
            gridKey: const Key('unified-spec-grid'),
            items: List<int>.generate(30, (index) => index),
            childAspectRatio: 1,
            itemBuilder: (_, item, __) => const SizedBox.shrink(),
          ),
        ),
      ),
    );

    final grid = tester.widget<GridView>(
      find.byKey(const Key('unified-spec-grid')),
    );
    final delegate =
        grid.gridDelegate as SliverGridDelegateWithFixedCrossAxisCount;
    // 2400 宽按统一目标宽 220 可排 10 列，由统一列数上限收敛到 8。
    expect(
      delegate.crossAxisCount,
      AppComponentTokens.defaults().cardGridMaxColumns,
    );
  });

  testWidgets('resolveAppCardGridColumnCount reads the unified token spec', (
    tester,
  ) async {
    late BuildContext ctx;
    await tester.pumpWidget(
      MaterialApp(
        theme: sakuraThemeData,
        home: Scaffold(
          body: Builder(
            builder: (context) {
              ctx = context;
              return const SizedBox.shrink();
            },
          ),
        ),
      ),
    );

    // (1200 + 12) / (220 + 12) = 5.2 → 5 列。
    expect(resolveAppCardGridColumnCount(ctx, width: 1200, spacing: 12), 5);
    expect(
      resolveAppCardGridColumnCount(ctx, width: 2400, spacing: 12),
      AppComponentTokens.defaults().cardGridMaxColumns,
    );
  });
}
