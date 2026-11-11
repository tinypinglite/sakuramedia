import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:material_ui/material_ui.dart';
import 'package:oktoast/oktoast.dart' show OKToast;
import 'package:sakuramedia/features/movies/data/dto/listing/movie_interaction_filter_options_dto.dart';
import 'package:sakuramedia/features/movies/presentation/controllers/listing/movie_filter_state.dart';
import 'package:sakuramedia/features/movies/presentation/providers/movie_interaction_filter_options_provider.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/feedback/app_toast.dart';
import 'package:sakuramedia/widgets/base/forms/app_picker_layout.dart';
import 'package:sakuramedia/widgets/base/forms/app_segmented_control.dart';
import 'package:sakuramedia/widgets/base/forms/app_text_field.dart';
import 'package:sakuramedia/widgets/base/navigation/app_glass_tab_bar.dart';
import 'package:sakuramedia/widgets/base/overlays/app_glass_filter_popover.dart';
import 'package:sakuramedia/widgets/base/overlays/app_glass_popover.dart';
import 'package:sakuramedia/widgets/base/layout/surface/app_surface_style.dart';
import 'package:sakuramedia/widgets/domain/movies/movie_filter_sections.dart';

import '../../../../support/pump_with_providers.dart';

void main() {
  testWidgets('扁平模式下输入框保留校验和输入', (tester) async {
    final formKey = GlobalKey<FormState>();
    final controller = TextEditingController();
    addTearDown(controller.dispose);

    await _pump(
      tester,
      Form(
        key: formKey,
        child: AppTextField(
          fieldKey: const Key('flat-text-field'),
          controller: controller,
          height: 40,
          validator: (value) =>
              value == null || value.trim().isEmpty ? '必填' : null,
        ),
      ),
    );

    expect(formKey.currentState!.validate(), isFalse);
    await tester.enterText(find.byKey(const Key('flat-text-field')), '扁平输入');
    await tester.pump();

    expect(controller.text, '扁平输入');
    expect(formKey.currentState!.validate(), isTrue);
  });

  testWidgets('扁平模式下分段控件保持选中和禁用语义', (tester) async {
    final changes = <int>[];
    await _pump(
      tester,
      AppSegmentedControl<int>(
        items: const <AppSegmentedItem<int>>[
          AppSegmentedItem(value: 0, label: '全部'),
          AppSegmentedItem(value: 1, label: '可播放'),
        ],
        selected: 0,
        layout: AppSegmentedLayout.fixed,
        onChanged: changes.add,
      ),
    );

    await tester.tap(find.text('可播放'));
    await tester.pumpAndSettle();
    expect(changes, <int>[1]);

    await _pump(
      tester,
      AppSegmentedControl<int>(
        items: const <AppSegmentedItem<int>>[
          AppSegmentedItem(value: 0, label: '全部'),
          AppSegmentedItem(value: 1, label: '可播放'),
        ],
        selected: 1,
        layout: AppSegmentedLayout.fixed,
        enabled: false,
        onChanged: changes.add,
      ),
    );

    await tester.tap(find.text('全部'), warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(changes, <int>[1]);
  });

  testWidgets('扁平模式下弹层可打开、关闭并保留面板内容', (tester) async {
    await _pump(
      tester,
      AppGlassPopover(
        panelKey: const Key('flat-popover-panel'),
        triggerBuilder: (context, toggle) => TextButton(
          key: const Key('flat-popover-trigger'),
          onPressed: toggle,
          child: const Text('打开'),
        ),
        contentBuilder: (context, close) => SizedBox(
          key: const Key('flat-popover-content'),
          width: 400,
          height: 320,
          child: const Text('筛选内容'),
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('flat-popover-trigger')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('flat-popover-panel')), findsOneWidget);
    expect(find.byKey(const Key('flat-popover-content')), findsOneWidget);

    await tester.tap(find.byKey(const Key('flat-popover-trigger')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('flat-popover-panel')), findsNothing);
  });

  testWidgets('扁平模式下弹层内容可独立滚动', (tester) async {
    await _pump(
      tester,
      AppGlassPopover(
        scrollable: true,
        scrollViewKey: const Key('flat-popover-scroll'),
        panelKey: const Key('flat-scroll-panel'),
        triggerBuilder: (context, toggle) => TextButton(
          key: const Key('flat-scroll-trigger'),
          onPressed: toggle,
          child: const Text('打开滚动'),
        ),
        contentBuilder: (context, close) => const SizedBox(height: 1200),
      ),
    );

    await tester.tap(find.byKey(const Key('flat-scroll-trigger')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('flat-scroll-panel')), findsOneWidget);

    await tester.drag(
      find.byKey(const Key('flat-popover-scroll')),
      const Offset(0, -180),
    );
    await tester.pumpAndSettle();
    final scrollable = tester.state<ScrollableState>(
      find.descendant(
        of: find.byKey(const Key('flat-popover-scroll')),
        matching: find.byType(Scrollable),
      ),
    );
    expect(scrollable.position.pixels, greaterThan(0));
    expect(tester.takeException(), isNull);
  });

  testWidgets('扁平模式下底部导航回传选中索引', (tester) async {
    var selected = -1;
    await _pump(
      tester,
      AppGlassTabBar(
        tabs: <AppGlassTabItem>[
          AppGlassTabItem(icon: const Icon(Icons.home_outlined), label: '首页'),
          AppGlassTabItem(icon: const Icon(Icons.movie_outlined), label: '影片'),
        ],
        selectedIndex: 0,
        onTabSelected: (index) => selected = index,
        barHeight: 64,
        verticalPadding: 4,
        horizontalPadding: 4,
        barBorderRadius: 28,
        iconSize: 24,
        labelFontSize: 10,
        selectedIconColor: Colors.blue,
        unselectedIconColor: Colors.grey,
        selectedLabelColor: Colors.blue,
        unselectedLabelColor: Colors.grey,
        selectedLabelStyle: const TextStyle(),
        unselectedLabelStyle: const TextStyle(),
      ),
      size: const Size(390, 844),
    );

    await tester.tap(find.text('影片'));
    await tester.pumpAndSettle();
    expect(selected, 1);
  });

  testWidgets('扁平模式下 Toast 正常渲染', (tester) async {
    await _pump(
      tester,
      const AppGlassToast(message: '扁平提示', tone: AppToastTone.success),
    );

    expect(tester.takeException(), isNull);
  });

  testWidgets('扁平模式下 OKToast 仍使用扁平表面', (tester) async {
    await tester.pumpWidget(
      AppSurfaceStyleScope(
        style: AppSurfaceStyle.flat,
        child: MaterialApp(
          theme: sakuraThemeData,
          builder: (context, child) =>
              OKToast(child: child ?? const SizedBox.shrink()),
          home: const Scaffold(body: SizedBox.expand()),
        ),
      ),
    );

    showToast(
      '扁平提示',
      tone: AppToastTone.success,
      duration: const Duration(milliseconds: 250),
    );
    await tester.pump(const Duration(milliseconds: 600));

    expect(tester.takeException(), isNull);
    dismissAllToast();
    await tester.pump();
  });

  testWidgets('扁平模式下 picker 分组行可点击', (tester) async {
    var taps = 0;
    const optionKey = Key('flat-picker-option');
    await _pump(
      tester,
      AppPickerIosSection(
        children: <Widget>[
          AppPickerIosRow(
            selected: true,
            showCheckmark: true,
            onTap: () => taps++,
            title: '收藏',
            optionKey: optionKey,
          ),
        ],
      ),
    );

    await tester.tap(find.byKey(optionKey));
    await tester.pump();
    expect(taps, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('扁平模式下弹层内容使用 LayoutBuilder 不触发 intrinsic 断言', (tester) async {
    await _pump(
      tester,
      AppGlassFilterPopover(
        panelKey: const Key('flat-layout-filter-panel'),
        triggerKey: const Key('flat-layout-filter-trigger'),
        label: '筛选',
        scrollable: true,
        scrollViewKey: const Key('flat-layout-filter-scroll'),
        panelBuilder: (context) => LayoutBuilder(
          builder: (context, constraints) => SizedBox(
            key: const Key('flat-layout-filter-content'),
            height: 240,
            child: Text('宽度 ${constraints.maxWidth.toStringAsFixed(0)}'),
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('flat-layout-filter-trigger')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('flat-layout-filter-panel')), findsOneWidget);
    expect(find.byKey(const Key('flat-layout-filter-content')), findsOneWidget);
    expect(
      tester
          .getSize(find.byKey(const Key('flat-layout-filter-content')))
          .height,
      240,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('扁平模式下影片筛选面板的年份 LayoutBuilder 正常布局', (tester) async {
    await _pump(
      tester,
      AppGlassFilterPopover(
        panelKey: const Key('flat-movie-filter-panel'),
        triggerKey: const Key('flat-movie-filter-trigger'),
        label: '筛选',
        scrollable: true,
        scrollViewKey: const Key('flat-movie-filter-scroll'),
        panelBuilder: (context) => MovieFilterSectionGroup(
          filterState: const MovieFilterState(),
          onChanged: (_) {},
        ),
      ),
      overrides: <Override>[
        movieInteractionFilterOptionsProvider.overrideWith(
          (ref) async => const MovieInteractionFilterOptionsDto(
            movieCount: 0,
            heat: MovieInteractionDistributionDto(p999: 100, max: 100),
            heatVersion: 'host:v6',
          ),
        ),
      ],
    );

    await tester.tap(find.byKey(const Key('flat-movie-filter-trigger')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('flat-movie-filter-panel')), findsOneWidget);
    expect(find.byKey(const Key('movie-filter-year-all')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

Future<void> _pump(
  WidgetTester tester,
  Widget home, {
  Size size = const Size(900, 700),
  List<Override> overrides = const <Override>[],
}) {
  return pumpWithProviders(
    tester,
    home: home,
    overrides: overrides,
    theme: sakuraDesktopThemeData,
    physicalSize: size,
    wrap: (child) => AppSurfaceStyleScope(
      style: AppSurfaceStyle.flat,
      child: Scaffold(body: child),
    ),
  );
}
