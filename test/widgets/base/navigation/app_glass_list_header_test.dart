import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/forms/app_filter_choice_section.dart';
import 'package:sakuramedia/widgets/base/forms/app_segmented_control.dart';
import 'package:sakuramedia/widgets/base/navigation/app_glass_list_header.dart';
import 'package:sakuramedia/widgets/base/overlays/app_glass_popover.dart';

import '../../../support/pump_with_providers.dart';

void main() {
  testWidgets('筛选弹层应用选项并保持打开，重置清除条件', (tester) async {
    final harness = _HarnessState();
    await _pump(tester, harness);

    await tester.tap(find.byKey(const Key('filter-trigger')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('未加入'));
    await tester.pumpAndSettle();

    expect(harness.filtered, isTrue);
    expect(find.byKey(const Key('filter-panel')), findsOne);

    await tester.tap(find.byKey(const Key('filter-reset')));
    await tester.pumpAndSettle();
    expect(harness.filtered, isFalse);
  });

  testWidgets('排序弹层应用选项并保持打开', (tester) async {
    final harness = _HarnessState();
    await _pump(tester, harness);

    await tester.tap(find.byKey(const Key('sort-trigger')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('最早'));
    await tester.pumpAndSettle();

    expect(harness.sort, '最早');
    expect(find.byKey(const Key('sort-panel')), findsOne);
  });

  testWidgets('选择入口回传点击', (tester) async {
    final harness = _HarnessState();
    await _pump(tester, harness);

    await tester.tap(find.byKey(const Key('enter-selection')));
    expect(harness.enteredSelection, isTrue);
  });

  testWidgets('控制条超出宽度时可横向滚动到尾部操作', (tester) async {
    await pumpWithProviders(
      tester,
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: 420,
            child: AppGlassListHeader(
              leading: SizedBox(
                width: 300,
                child: AppGlassFilterGroup(
                  label: '全部',
                  onTap: () {},
                  info: <Widget>[const AppGlassHeaderText(label: '8 个')],
                ),
              ),
              trailing: SizedBox(
                width: 260,
                child: AppGlassHeaderGroup(
                  children: <Widget>[
                    AppGlassHeaderButton(
                      key: const Key('scroll-target'),
                      icon: Icons.check_circle_outline,
                      label: '选择',
                      onTap: () {},
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
      theme: sakuraDesktopThemeData,
      physicalSize: const Size(600, 400),
    );
    await tester.pumpAndSettle();

    final scrollable = tester.state<ScrollableState>(
      find.descendant(
        of: find.byType(AppGlassListHeader),
        matching: find.byType(Scrollable),
      ),
    );
    expect(scrollable.position.maxScrollExtent, greaterThan(0));

    await tester.drag(find.byType(AppGlassListHeader), const Offset(-200, 0));
    await tester.pumpAndSettle();
    expect(scrollable.position.pixels, greaterThan(0));
    expect(tester.takeException(), isNull);
  });

  testWidgets('玻璃多选头触发退出、全选和批量动作', (tester) async {
    final harness = _HarnessState();
    await pumpWithProviders(
      tester,
      home: Scaffold(
        body: Padding(
          padding: const EdgeInsets.all(24),
          child: AppGlassSelectionHeader(
            selectionLabel: '已选 2 个',
            selectAllLabel: '全选',
            onExitSelection: () => harness.exitCount++,
            onToggleAll: () => harness.toggleAllCount++,
            exitKey: const Key('selection-exit'),
            selectAllKey: const Key('selection-all'),
            actions: <AppGlassSelectionAction>[
              AppGlassSelectionAction(
                key: const Key('selection-add'),
                label: '加入',
                icon: Icons.playlist_add_rounded,
                onTap: () => harness.addCount++,
              ),
            ],
          ),
        ),
      ),
      theme: sakuraDesktopThemeData,
      physicalSize: const Size(1100, 700),
    );

    await tester.tap(find.byKey(const Key('selection-exit')));
    await tester.tap(find.byKey(const Key('selection-all')));
    await tester.tap(find.byKey(const Key('selection-add')));

    expect(harness.exitCount, 1);
    expect(harness.toggleAllCount, 1);
    expect(harness.addCount, 1);
  });
}

class _HarnessState {
  bool filtered = false;
  String sort = '最新';
  bool enteredSelection = false;
  int exitCount = 0;
  int toggleAllCount = 0;
  int addCount = 0;
}

Future<void> _pump(WidgetTester tester, _HarnessState harness) {
  return pumpWithProviders(
    tester,
    home: _Harness(harness: harness),
    theme: sakuraDesktopThemeData,
    physicalSize: const Size(1100, 700),
  );
}

class _Harness extends StatefulWidget {
  const _Harness({required this.harness});

  final _HarnessState harness;

  @override
  State<_Harness> createState() => _HarnessStateWidget();
}

class _HarnessStateWidget extends State<_Harness> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Align(
          alignment: Alignment.topCenter,
          child: SizedBox(
            width: 900,
            child: AppGlassListHeader(
              leading: AppGlassPopover(
                panelKey: const Key('filter-panel'),
                footer: AppGlassFilterFooter(
                  isDefault: !widget.harness.filtered,
                  onReset: () =>
                      setState(() => widget.harness.filtered = false),
                  resetKey: const Key('filter-reset'),
                ),
                triggerBuilder: (context, toggle) => AppGlassFilterGroup(
                  buttonKey: const Key('filter-trigger'),
                  label: widget.harness.filtered ? '未加入' : '全部',
                  onTap: toggle,
                  info: <Widget>[const AppGlassHeaderText(label: '8 个')],
                ),
                contentBuilder: (context, close) =>
                    AppFilterChoiceSection<bool>(
                      title: '归属',
                      items: const <AppSegmentedItem<bool>>[
                        AppSegmentedItem(value: false, label: '全部'),
                        AppSegmentedItem(value: true, label: '未加入'),
                      ],
                      selected: widget.harness.filtered,
                      onChanged: (value) =>
                          setState(() => widget.harness.filtered = value),
                    ),
              ),
              trailing: AppGlassPopover(
                panelKey: const Key('sort-panel'),
                triggerBuilder: (context, toggle) => AppGlassHeaderGroup(
                  children: <Widget>[
                    AppGlassHeaderButton(
                      key: const Key('sort-trigger'),
                      icon: Icons.swap_vert_rounded,
                      label: widget.harness.sort,
                      trailingIcon: Icons.expand_more_rounded,
                      onTap: toggle,
                    ),
                    AppGlassHeaderButton(
                      key: const Key('enter-selection'),
                      icon: Icons.check_circle_outline,
                      label: '选择',
                      onTap: () => widget.harness.enteredSelection = true,
                    ),
                  ],
                ),
                contentBuilder: (context, close) =>
                    AppFilterChoiceSection<String>(
                      title: '排序',
                      items: const <AppSegmentedItem<String>>[
                        AppSegmentedItem(value: '最新', label: '最新'),
                        AppSegmentedItem(value: '最早', label: '最早'),
                      ],
                      selected: widget.harness.sort,
                      onChanged: (value) =>
                          setState(() => widget.harness.sort = value),
                    ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
