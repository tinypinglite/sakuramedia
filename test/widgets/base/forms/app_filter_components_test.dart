import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/forms/app_filter_choice_section.dart';
import 'package:sakuramedia/widgets/base/forms/app_filter_chip.dart';
import 'package:sakuramedia/widgets/base/forms/app_filter_range_section.dart';
import 'package:sakuramedia/widgets/base/forms/app_segmented_control.dart';

import '../../../support/pump_with_providers.dart';

void main() {
  group('AppSegmentedControl', () {
    testWidgets('重复点击当前项不重复回调', (tester) async {
      final changes = <int>[];

      await _pump(
        tester,
        child: AppSegmentedControl<int>(
          items: const [
            AppSegmentedItem(value: 0, label: '全部'),
            AppSegmentedItem(value: 1, label: '可播放'),
          ],
          selected: 0,
          layout: AppSegmentedLayout.fixed,
          onChanged: changes.add,
        ),
      );

      await tester.tap(find.text('全部'));
      await tester.pumpAndSettle();
      expect(changes, isEmpty);

      await tester.tap(find.text('可播放'));
      await tester.pumpAndSettle();
      expect(changes, <int>[1]);

      await tester.tap(find.text('可播放'));
      await tester.pumpAndSettle();
      expect(changes, <int>[1]);
    });
  });

  group('AppFilterChoiceSection', () {
    testWidgets('单选分段透传选中值，禁用后不再回调', (tester) async {
      final changes = <int>[];

      await _pump(
        tester,
        child: AppFilterChoiceSection<int>(
          title: '状态',
          items: const [
            AppSegmentedItem(value: 0, label: '全部'),
            AppSegmentedItem(value: 1, label: '可播放'),
          ],
          selected: 0,
          onChanged: changes.add,
        ),
      );

      await tester.tap(find.text('可播放'));
      await tester.pumpAndSettle();
      expect(changes, [1]);

      await _pump(
        tester,
        child: AppFilterChoiceSection<int>(
          title: '状态',
          items: const [
            AppSegmentedItem(value: 0, label: '全部'),
            AppSegmentedItem(value: 1, label: '可播放'),
          ],
          selected: 1,
          enabled: false,
          onChanged: changes.add,
        ),
      );

      await tester.tap(find.text('全部'), warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(changes, [1]);
    });

    testWidgets('空选项与加载占位不抛异常', (tester) async {
      await _pump(
        tester,
        child: const AppFilterChoiceSection<int>(
          title: '状态',
          items: [],
          selected: null,
          onChanged: _ignoreInt,
        ),
      );
      expect(tester.takeException(), isNull);

      await _pump(
        tester,
        child: AppFilterChoiceSection<int>(
          title: '状态',
          items: const [
            AppSegmentedItem(value: 0, label: '全部'),
            AppSegmentedItem(value: 1, label: '可播放'),
          ],
          selected: 1,
          isLoading: true,
          onChanged: _ignoreInt,
        ),
      );
      expect(tester.takeException(), isNull);
    });
  });

  group('AppFilterOptionSection', () {
    testWidgets('映射选项、标签和选中回调', (tester) async {
      final changes = <int>[];

      await _pump(
        tester,
        child: AppFilterOptionSection<int>(
          title: '状态',
          options: const <int>[0, 1],
          selectedValue: 0,
          labelBuilder: (value) => value == 0 ? '全部' : '可播放',
          optionKeyBuilder: (value) => Key('option-$value'),
          onSelected: changes.add,
        ),
      );

      expect(find.text('全部'), findsOneWidget);
      expect(find.text('可播放'), findsOneWidget);

      await tester.tap(find.text('可播放'));
      await tester.pumpAndSettle();
      expect(changes, <int>[1]);
    });

    testWidgets('选中值不存在时回退到第一项且不触发回调', (tester) async {
      var changes = 0;

      await _pump(
        tester,
        child: AppFilterOptionSection<int>(
          title: '状态',
          options: const <int>[0, 1],
          selectedValue: 99,
          labelBuilder: (value) => value == 0 ? '全部' : '可播放',
          onSelected: (_) => changes++,
        ),
      );

      final control = tester.widget<AppSegmentedControl<int>>(
        find.byType(AppSegmentedControl<int>),
      );
      expect(control.selected, 0);
      expect(changes, 0);
    });
  });

  group('AppFilterChip', () {
    testWidgets('点击与禁用状态', (tester) async {
      var taps = 0;
      await _pump(
        tester,
        child: AppFilterChip(
          label: '标签',
          selected: false,
          onPressed: () => taps++,
        ),
      );
      await tester.tap(find.text('标签'));
      await tester.pump();
      expect(taps, 1);

      await _pump(
        tester,
        child: AppFilterChip(
          label: '标签',
          selected: true,
          enabled: false,
          onPressed: () => taps++,
        ),
      );
      await tester.tap(find.text('标签'));
      await tester.pump();
      expect(taps, 1);
    });
  });

  group('AppFilterRangeSection', () {
    testWidgets('拖动结束才应用，外部值会同步回滑块', (tester) async {
      RangeValues? applied;
      const sliderKey = Key('range-slider');

      await _pump(
        tester,
        child: AppFilterRangeSection(
          title: '热度',
          values: const RangeValues(0, 100),
          min: 0,
          max: 100,
          valueLabelBuilder: (values) =>
              '${values.start.round()} ~ ${values.end.round()}',
          minLabel: '0',
          maxLabel: '100',
          sliderKey: sliderKey,
          onChangeEnd: (values) => applied = values,
        ),
      );

      await tester.drag(find.byKey(sliderKey), const Offset(-80, 0));
      await tester.pumpAndSettle();
      expect(applied, isNotNull);

      await _pump(
        tester,
        child: AppFilterRangeSection(
          title: '热度',
          values: const RangeValues(25, 75),
          min: 0,
          max: 100,
          valueLabelBuilder: (values) =>
              '${values.start.round()} ~ ${values.end.round()}',
          minLabel: '0',
          maxLabel: '100',
          sliderKey: sliderKey,
          onChangeEnd: (values) => applied = values,
        ),
      );
      final slider = tester.widget<RangeSlider>(find.byKey(sliderKey));
      expect(slider.values, const RangeValues(25, 75));
    });

    testWidgets('禁用时不应用拖动', (tester) async {
      RangeValues? applied;
      await _pump(
        tester,
        child: AppFilterRangeSection(
          title: '热度',
          values: const RangeValues(0, 100),
          min: 0,
          max: 100,
          enabled: false,
          valueLabelBuilder: (values) =>
              '${values.start.round()} ~ ${values.end.round()}',
          minLabel: '0',
          maxLabel: '100',
          sliderKey: const Key('disabled-range-slider'),
          onChangeEnd: (values) => applied = values,
        ),
      );

      await tester.drag(
        find.byKey(const Key('disabled-range-slider')),
        const Offset(-80, 0),
      );
      await tester.pumpAndSettle();
      expect(applied, isNull);
    });
  });

  testWidgets('auto 分段在多选项和窄宽度下不溢出', (tester) async {
    await _pump(
      tester,
      width: 320,
      child: AppSegmentedControl<int>(
        items: [
          for (var index = 0; index < 8; index++)
            AppSegmentedItem(value: index, label: '选项$index'),
        ],
        selected: 0,
        layout: AppSegmentedLayout.auto,
        onChanged: _ignoreInt,
      ),
    );
    expect(tester.takeException(), isNull);
  });
}

void _ignoreInt(int _) {}

Future<void> _pump(
  WidgetTester tester, {
  required Widget child,
  double width = 400,
}) {
  return pumpWithProviders(
    tester,
    home: child,
    theme: sakuraDesktopThemeData,
    physicalSize: Size(width, 640),
    wrap: (child) => Scaffold(
      body: Padding(padding: const EdgeInsets.all(16), child: child),
    ),
  );
}
