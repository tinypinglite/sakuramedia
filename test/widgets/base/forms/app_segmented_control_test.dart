import 'package:material_ui/material_ui.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/forms/app_segmented_control.dart';
import 'package:sakuramedia/widgets/base/layout/glass/app_glass_surface.dart';

void main() {
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

    expect(find.byKey(const Key('segment-a')), findsOneWidget);
    expect(find.byKey(const Key('segment-b')), findsOneWidget);
    final track = tester.widget<AppGlassSurface>(
      find.byType(AppGlassSurface).first,
    );
    expect(track.tone, AppGlassTone.track);

    await tester.tap(find.byKey(const Key('segment-b')));
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

    final selected = tester.widget<AnimatedContainer>(
      find.descendant(
        of: find.byKey(const Key('segment-a')),
        matching: find.byType(AnimatedContainer),
      ),
    );
    final decoration = selected.decoration! as BoxDecoration;

    expect(decoration.color, darkTheme.appColors.surfaceElevated);
    expect(decoration.border, isNotNull);
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
            of: find.byKey(const Key('segment-a')),
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
              of: find.byKey(const Key('segment-a')),
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

    final itemA = tester.getRect(find.byKey(const Key('segment-a')));
    final itemB = tester.getRect(find.byKey(const Key('segment-b')));
    await tester.tap(find.byKey(const Key('segment-b')));
    await tester.pumpAndSettle();

    expect(tester.getRect(find.byKey(const Key('segment-a'))), itemA);
    expect(tester.getRect(find.byKey(const Key('segment-b'))), itemB);
  });
}

void _noop(String value) {}
