import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/forms/app_segmented_control.dart';
import 'package:sakuramedia/widgets/base/layout/glass/app_glass_surface.dart';

void main() {
  setUpAll(() async {
    await LiquidGlassWidgets.initialize(enablePerformanceMonitor: false);
  });

  testWidgets('renders items and forwards selection', (
    WidgetTester tester,
  ) async {
    final changes = <String>[];

    await tester.pumpWidget(
      MaterialApp(
        theme: sakuraThemeData,
        home: Scaffold(
          body: AppSegmentedControl<String>(
            items: const <AppSegmentedItem<String>>[
              AppSegmentedItem<String>(
                key: Key('segment-a'),
                value: 'a',
                label: 'A',
              ),
              AppSegmentedItem<String>(
                key: Key('segment-b'),
                value: 'b',
                label: 'B',
              ),
            ],
            selected: 'a',
            onChanged: changes.add,
          ),
        ),
      ),
    );

    expect(find.byType(GlassSegmentedControl), findsOneWidget);
    expect(find.byType(AppGlassSurface), findsNothing);
    final control = tester.widget<GlassSegmentedControl>(
      find.byType(GlassSegmentedControl),
    );
    expect(control.isScrollable, isTrue);
    expect(control.selectedIndex, 0);
    expect(control.segments.map((segment) => segment.label), <String>[
      'A',
      'B',
    ]);
    expect(control.segments.first.id, const Key('segment-a'));

    await tester.tap(find.text('B'));
    await tester.pump();

    expect(changes, <String>['b']);
  });

  testWidgets('selected pill uses the raised surface in dark mode', (
    WidgetTester tester,
  ) async {
    final darkTheme = buildSakuraDesktopThemeData(brightness: Brightness.dark);

    await tester.pumpWidget(
      MaterialApp(
        theme: darkTheme,
        home: const Scaffold(
          body: AppSegmentedControl<String>(
            items: <AppSegmentedItem<String>>[
              AppSegmentedItem<String>(
                key: Key('segment-a'),
                value: 'a',
                label: 'A',
              ),
              AppSegmentedItem<String>(
                key: Key('segment-b'),
                value: 'b',
                label: 'B',
              ),
            ],
            selected: 'a',
            onChanged: _noop,
          ),
        ),
      ),
    );

    final control = tester.widget<GlassSegmentedControl>(
      find.byType(GlassSegmentedControl),
    );

    expect(control.indicatorColor, darkTheme.appColors.surfaceElevated);
    expect(control.selectedTextStyle?.color, darkTheme.appTextPalette.primary);
    expect(
      control.unselectedTextStyle?.color,
      darkTheme.appTextPalette.secondary,
    );
  });

  testWidgets('inherits the ambient font family', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: sakuraThemeData,
        home: const Scaffold(
          body: DefaultTextStyle(
            style: TextStyle(fontFamily: 'PreviewCjk'),
            child: AppSegmentedControl<String>(
              items: <AppSegmentedItem<String>>[
                AppSegmentedItem<String>(
                  key: Key('segment-a'),
                  value: 'a',
                  label: 'A',
                ),
                AppSegmentedItem<String>(
                  key: Key('segment-b'),
                  value: 'b',
                  label: 'B',
                ),
              ],
              selected: 'a',
              onChanged: _noop,
            ),
          ),
        ),
      ),
    );

    final labelStyles = tester
        .widgetList<AnimatedDefaultTextStyle>(
          find.descendant(
            of: find.byType(GlassSegmentedControl),
            matching: find.byType(AnimatedDefaultTextStyle),
          ),
        )
        .map((widget) => widget.style.fontFamily);
    expect(labelStyles, contains('PreviewCjk'));
  });

  testWidgets('keeps the resolved Windows font over the ambient font', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    try {
      await tester.pumpWidget(
        MaterialApp(
          theme: sakuraThemeData,
          home: const Scaffold(
            body: DefaultTextStyle(
              style: TextStyle(fontFamily: 'PreviewCjk'),
              child: AppSegmentedControl<String>(
                items: <AppSegmentedItem<String>>[
                  AppSegmentedItem<String>(
                    key: Key('segment-a'),
                    value: 'a',
                    label: 'A',
                  ),
                  AppSegmentedItem<String>(
                    key: Key('segment-b'),
                    value: 'b',
                    label: 'B',
                  ),
                ],
                selected: 'a',
                onChanged: _noop,
              ),
            ),
          ),
        ),
      );

      final labelStyles = tester
          .widgetList<AnimatedDefaultTextStyle>(
            find.descendant(
              of: find.byType(GlassSegmentedControl),
              matching: find.byType(AnimatedDefaultTextStyle),
            ),
          )
          .map((widget) => widget.style.fontFamily);
      expect(labelStyles, contains(kAppWindowsFontFamily));
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('selection does not reflow segment geometry', (tester) async {
    var selected = 'a';

    await tester.pumpWidget(
      MaterialApp(
        theme: sakuraThemeData,
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) {
              return AppSegmentedControl<String>(
                items: const <AppSegmentedItem<String>>[
                  AppSegmentedItem<String>(
                    key: Key('segment-a'),
                    value: 'a',
                    label: 'A',
                  ),
                  AppSegmentedItem<String>(
                    key: Key('segment-b'),
                    value: 'b',
                    label: 'B',
                  ),
                ],
                selected: selected,
                onChanged: (value) => setState(() => selected = value),
              );
            },
          ),
        ),
      ),
    );

    final itemA = tester.getRect(find.text('A'));
    final itemB = tester.getRect(find.text('B'));
    await tester.tap(find.text('B'));
    await tester.pumpAndSettle();

    expect(tester.getRect(find.text('A')), itemA);
    expect(tester.getRect(find.text('B')), itemB);
  });

  testWidgets('loose bounded width keeps natural segment widths', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: sakuraThemeData,
        home: Scaffold(
          body: Align(
            alignment: Alignment.centerLeft,
            child: AppSegmentedControl<String>(
              items: const <AppSegmentedItem<String>>[
                AppSegmentedItem<String>(value: 'a', label: 'A'),
                AppSegmentedItem<String>(value: 'b', label: 'B'),
              ],
              selected: 'a',
              onChanged: (_) {},
            ),
          ),
        ),
      ),
    );

    final control = tester.widget<GlassSegmentedControl>(
      find.byType(GlassSegmentedControl),
    );
    expect(control.isScrollable, isTrue);
    expect(
      tester.getSize(find.byType(GlassSegmentedControl)).width,
      lessThan(300),
    );
  });

  testWidgets('keeps natural widths inside a constrained parent', (
    tester,
  ) async {
    final changes = <String>[];

    await tester.pumpWidget(
      LiquidGlassWidgets.wrap(
        brightnessResolver: Theme.maybeBrightnessOf,
        child: MaterialApp(
          theme: sakuraThemeData,
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 180,
                child: AppSegmentedControl<String>(
                  items: const <AppSegmentedItem<String>>[
                    AppSegmentedItem<String>(value: 'a', label: 'A'),
                    AppSegmentedItem<String>(value: 'b', label: 'B'),
                    AppSegmentedItem<String>(value: 'c', label: 'C'),
                  ],
                  selected: 'b',
                  onChanged: changes.add,
                ),
              ),
            ),
          ),
        ),
      ),
    );

    final control = tester.widget<GlassSegmentedControl>(
      find.byType(GlassSegmentedControl),
    );
    expect(control.isScrollable, isTrue);
    expect(control.selectedIndex, 1);

    await tester.tap(find.text('C'));
    await tester.pump();

    expect(changes, <String>['c']);
  });
}

void _noop(String value) {}
