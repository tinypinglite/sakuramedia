import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/actions/app_text_button.dart';
import 'package:sakuramedia/widgets/base/layout/scrolling/app_filter_total_header.dart';
import 'package:sakuramedia/widgets/base/navigation/app_list_header.dart';

void main() {
  Widget wrap(Widget child) {
    return MaterialApp(theme: sakuraThemeData, home: Scaffold(body: child));
  }

  testWidgets('常规态按筛选、只读信息、操作的顺序渲染', (tester) async {
    await tester.pumpWidget(
      wrap(
        AppListHeader(
          filterButtonKey: const Key('filter'),
          onFilterTap: () {},
          informationSlots: const [
            AppListHeaderInfo(key: Key('summary'), label: '已订阅 · 最近订阅'),
            AppListHeaderInfo(key: Key('total'), label: '28 部'),
          ],
          actionSlots: [
            AppTextButton(
              key: const Key('selection'),
              label: '选择',
              onPressed: () {},
            ),
          ],
        ),
      ),
    );

    final filterX = tester.getCenter(find.byKey(const Key('filter'))).dx;
    final summaryX = tester.getCenter(find.byKey(const Key('summary'))).dx;
    final totalX = tester.getCenter(find.byKey(const Key('total'))).dx;
    final selectionX = tester.getCenter(find.byKey(const Key('selection'))).dx;

    expect(filterX, lessThan(summaryX));
    expect(summaryX, lessThan(totalX));
    expect(totalX, lessThan(selectionX));
  });

  testWidgets('筛选入口始终位于最左侧并触发回调', (tester) async {
    var taps = 0;
    await tester.pumpWidget(
      wrap(
        AppListHeader(
          filterButtonKey: const Key('filter'),
          onFilterTap: () => taps += 1,
        ),
      ),
    );

    expect(find.byIcon(Icons.tune_rounded), findsOneWidget);

    await tester.tap(find.byKey(const Key('filter')));
    await tester.pump();

    expect(taps, 1);
  });

  testWidgets('筛选入口带摘要时显示摘要与下拉箭头', (tester) async {
    await tester.pumpWidget(
      wrap(
        AppListHeader(
          filterButtonKey: const Key('filter'),
          filterLabel: '全部 · 单体',
          onFilterTap: () {},
        ),
      ),
    );

    expect(find.text('全部 · 单体'), findsOneWidget);
    expect(find.byIcon(Icons.expand_more_rounded), findsOneWidget);
  });

  testWidgets('筛选入口的点按区域达到 44 的最小尺寸', (tester) async {
    await tester.pumpWidget(
      wrap(
        AppListHeader(
          filterButtonKey: const Key('filter'),
          filterLabel: '全部 · 单体',
          onFilterTap: () {},
        ),
      ),
    );

    // 视觉胶囊比这矮，但手势区撑满整行高度，命中区必须够 44。
    final size = tester.getSize(find.byKey(const Key('filter')));
    expect(size.height, greaterThanOrEqualTo(44));
    expect(size.width, greaterThanOrEqualTo(44));
  });

  testWidgets('筛选入口外观不随筛选是否生效而变化', (tester) async {
    final colors = sakuraThemeData.extension<AppColors>()!;

    Future<BoxDecoration> decorationFor(String label) async {
      await tester.pumpWidget(
        wrap(
          AppListHeader(
            filterButtonKey: const Key('filter'),
            filterLabel: label,
            onFilterTap: () {},
          ),
        ),
      );
      final container = tester.widget<Container>(
        find
            .descendant(
              of: find.byKey(const Key('filter')),
              matching: find.byType(Container),
            )
            .first,
      );
      return container.decoration! as BoxDecoration;
    }

    // 入口是常驻操作，默认态与「已筛选」态必须长得一模一样：变色会让同一个
    // 按钮看起来像两个不同控件。当前筛选值由标签文字本身表达。
    final idle = await decorationFor('全部');
    final filtered = await decorationFor('已订阅');

    expect(idle.color, colors.surfaceMuted);
    expect(filtered.color, colors.surfaceMuted);
  });

  testWidgets('信息插槽不提供点击能力，操作插槽可以触发', (tester) async {
    var actionTaps = 0;
    await tester.pumpWidget(
      wrap(
        AppListHeader(
          onFilterTap: () {},
          informationSlots: const [
            AppListHeaderInfo(
              key: Key('updated-at'),
              label: '更新于 10:30',
              icon: Icons.schedule_rounded,
            ),
          ],
          actionSlots: [
            AppTextButton(
              key: const Key('more'),
              label: '更多',
              onPressed: () => actionTaps += 1,
            ),
          ],
        ),
      ),
    );

    expect(
      find.descendant(
        of: find.byKey(const Key('updated-at')),
        matching: find.byType(InkWell),
      ),
      findsNothing,
    );
    await tester.tap(find.byKey(const Key('more')));
    await tester.pump();
    expect(actionTaps, 1);
  });

  testWidgets('选择态改写整条顶栏并隐藏筛选与常规信息', (tester) async {
    var exits = 0;
    await tester.pumpWidget(
      wrap(
        AppListHeader.selection(
          selectionLabel: '已选 3 部',
          selectionExitButtonKey: const Key('exit'),
          onExitSelection: () => exits += 1,
          actionSlots: [
            AppButtonForTest(key: const Key('select-all'), label: '全选(20)'),
            AppButtonForTest(key: const Key('subscribe'), label: '订阅'),
          ],
        ),
      ),
    );

    expect(find.byIcon(Icons.tune_rounded), findsNothing);
    expect(find.byIcon(Icons.close_rounded), findsOneWidget);
    expect(find.text('已选 3 部'), findsOneWidget);
    expect(find.text('全选(20)'), findsOneWidget);
    expect(find.text('订阅'), findsOneWidget);

    await tester.tap(find.byKey(const Key('exit')));
    await tester.pump();
    expect(exits, 1);
  });

  testWidgets('窄屏下大量插槽横向滚动且不溢出', (tester) async {
    await tester.binding.setSurfaceSize(const Size(240, 400));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      wrap(
        AppListHeader(
          onFilterTap: () {},
          informationSlots: const [
            AppListHeaderInfo(label: '来源 · 很长的排行榜名称'),
            AppListHeaderInfo(label: '更新于 2026-07-25 10:30'),
          ],
          actionSlots: const [
            AppButtonForTest(label: '新建'),
            AppButtonForTest(label: '查看全部'),
            AppButtonForTest(label: '选择'),
          ],
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.byType(SingleChildScrollView), findsOneWidget);
  });

  testWidgets('常规态与多选态、以及与 AppFilterTotalHeader 高度一致', (tester) async {
    Future<double> heightOf(Widget child) async {
      await tester.pumpWidget(
        wrap(KeyedSubtree(key: const Key('probe'), child: child)),
      );
      return tester.getSize(find.byKey(const Key('probe'))).height;
    }

    final normal = await heightOf(
      AppListHeader(
        filterLabel: '全部',
        onFilterTap: () {},
        informationSlots: const [AppListHeaderInfo(label: '128 部')],
      ),
    );
    final selection = await heightOf(
      AppListHeader.selection(selectionLabel: '已选 2 部', onExitSelection: () {}),
    );
    final legacy = await heightOf(
      const AppFilterTotalHeader(
        leading: SizedBox.shrink(),
        totalText: '128 部',
      ),
    );

    // 进出多选、以及尚未迁移的页面之间，都不该出现高度跳变。
    expect(selection, normal);
    expect(legacy, normal);
  });
}

class AppButtonForTest extends StatelessWidget {
  const AppButtonForTest({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(label);
  }
}
