import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/layout/grids/app_adaptive_card_grid.dart';
import 'package:sakuramedia/widgets/base/layout/grids/app_adaptive_card_wrap.dart';
import 'package:sakuramedia/widgets/base/layout/grids/grid_column_resolver.dart';

void main() {
  testWidgets('固定比例网格滚动时不重建已挂载卡片', (tester) async {
    final buildCounts = <int, int>{};
    final controller = ScrollController();
    addTearDown(controller.dispose);

    await _pumpScrollView(
      tester,
      controller: controller,
      sliver: AppAdaptiveCardSliver<int>(
        items: List<int>.generate(60, (index) => index),
        targetColumnWidth: 100,
        childAspectRatio: 1,
        itemBuilder: _countedItemBuilder(buildCounts),
      ),
    );

    expect(find.text('item-0'), findsOneWidget);
    final initialBuilds = buildCounts[0]!;

    controller.jumpTo(20);
    await tester.pump();

    expect(buildCounts[0], initialBuilds);
  });

  testWidgets('瀑布流网格滚动时不重建已挂载卡片', (tester) async {
    final buildCounts = <int, int>{};
    final controller = ScrollController();
    addTearDown(controller.dispose);

    await _pumpScrollView(
      tester,
      controller: controller,
      sliver: AppAdaptiveCardSliver<int>(
        items: List<int>.generate(60, (index) => index),
        targetColumnWidth: 100,
        layout: AppAdaptiveCardGridLayout.masonry,
        tileAspect: (_) => 1,
        itemBuilder: _countedItemBuilder(buildCounts),
      ),
    );

    expect(find.text('item-0'), findsOneWidget);
    final initialBuilds = buildCounts[0]!;

    controller.jumpTo(20);
    await tester.pump();

    expect(buildCounts[0], initialBuilds);
  });

  testWidgets('单列自然高度网格滚动时不重建已挂载卡片', (tester) async {
    final buildCounts = <int, int>{};
    final controller = ScrollController();
    addTearDown(controller.dispose);

    await _pumpScrollView(
      tester,
      controller: controller,
      sliver: AppAdaptiveCardWrapSliver<int>(
        items: List<int>.generate(30, (index) => index),
        orientation: AppCardGridOrientation.mixed,
        minColumns: 1,
        maxColumns: 2,
        stretchRows: true,
        itemBuilder: _countedItemBuilder(buildCounts),
      ),
    );

    expect(find.text('item-0'), findsOneWidget);
    final initialBuilds = buildCounts[0]!;

    controller.jumpTo(20);
    await tester.pump();

    expect(buildCounts[0], initialBuilds);
  });

  testWidgets('多列自然高度网格滚动时不重建已挂载卡片', (tester) async {
    final buildCounts = <int, int>{};
    final controller = ScrollController();
    addTearDown(controller.dispose);

    await _pumpScrollView(
      tester,
      controller: controller,
      size: const Size(900, 800),
      sliver: AppAdaptiveCardWrapSliver<int>(
        items: List<int>.generate(30, (index) => index),
        orientation: AppCardGridOrientation.mixed,
        minColumns: 1,
        maxColumns: 2,
        stretchRows: true,
        itemBuilder: _countedItemBuilder(buildCounts),
      ),
    );

    expect(find.text('item-0'), findsOneWidget);
    final initialBuilds = buildCounts[0]!;

    controller.jumpTo(20);
    await tester.pump();

    expect(buildCounts[0], initialBuilds);
  });

  testWidgets('宽度变化后重新布局网格', (tester) async {
    final buildCounts = <int, int>{};
    final controller = ScrollController();
    addTearDown(controller.dispose);

    await _pumpScrollView(
      tester,
      controller: controller,
      sliver: AppAdaptiveCardWrapSliver<int>(
        items: List<int>.generate(4, (index) => index),
        orientation: AppCardGridOrientation.mixed,
        minColumns: 1,
        maxColumns: 2,
        itemBuilder: _countedItemBuilder(buildCounts),
      ),
    );
    final initialBuilds = buildCounts[0]!;

    tester.view.physicalSize = const Size(900, 800);
    await tester.pump();

    expect(buildCounts[0], greaterThan(initialBuilds));
  });

  testWidgets('父级数据变化后重建并使用新的 itemBuilder', (tester) async {
    final harnessKey = GlobalKey<_WrapHarnessState>();
    await _pump(tester, child: _WrapHarness(key: harnessKey));

    expect(find.text('old'), findsOneWidget);

    harnessKey.currentState!.updateLabel('new');
    await tester.pump();

    expect(find.text('new'), findsOneWidget);
    expect(find.text('old'), findsNothing);
  });
}

Widget Function(BuildContext, int, int) _countedItemBuilder(
  Map<int, int> buildCounts,
) {
  return (_, item, _) {
    buildCounts[item] = (buildCounts[item] ?? 0) + 1;
    return SizedBox(height: 100, child: Text('item-$item'));
  };
}

Future<void> _pumpScrollView(
  WidgetTester tester, {
  required ScrollController controller,
  required Widget sliver,
  Size size = const Size(400, 800),
}) {
  return _pump(
    tester,
    size: size,
    child: CustomScrollView(controller: controller, slivers: <Widget>[sliver]),
  );
}

Future<void> _pump(
  WidgetTester tester, {
  required Widget child,
  Size size = const Size(400, 800),
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });

  await tester.pumpWidget(
    MaterialApp(
      theme: sakuraThemeData,
      home: Scaffold(body: child),
    ),
  );
  await tester.pump();
}

class _WrapHarness extends StatefulWidget {
  const _WrapHarness({super.key});

  @override
  State<_WrapHarness> createState() => _WrapHarnessState();
}

class _WrapHarnessState extends State<_WrapHarness> {
  String label = 'old';

  void updateLabel(String value) {
    setState(() => label = value);
  }

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: <Widget>[
        AppAdaptiveCardWrapSliver<String>(
          items: <String>[label],
          orientation: AppCardGridOrientation.mixed,
          minColumns: 1,
          maxColumns: 1,
          itemBuilder: (context, item, _) => Text(item),
        ),
      ],
    );
  }
}
