import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/features/shared/data/sort_direction.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/forms/app_segmented_control.dart';
import 'package:sakuramedia/widgets/base/navigation/app_sort_menu_button.dart';

import '../../../support/pump_with_providers.dart';

void main() {
  testWidgets('desktop sort closes after field and direction changes', (
    tester,
  ) async {
    int? selectedField;
    SortDirection? selectedDirection;
    await pumpWithProviders(
      tester,
      home: Scaffold(
        body: Center(
          child: _DesktopSortHarness(
            onFieldChanged: (field) => selectedField = field,
            onDirectionChanged: (direction) => selectedDirection = direction,
          ),
        ),
      ),
      theme: buildSakuraDesktopThemeData(),
      physicalSize: const Size(1100, 700),
    );

    await tester.tap(find.byKey(const Key('sort-desktop-trigger')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('sort-desktop-panel')), findsOneWidget);
    expect(find.byKey(const Key('sort-field-control')), findsOneWidget);
    expect(find.byKey(const Key('sort-direction-control')), findsOneWidget);

    await tester.tap(_panelText('sort-desktop-panel', '标题'));
    await tester.pumpAndSettle();

    expect(selectedField, 2);
    expect(find.byKey(const Key('sort-desktop-panel')), findsNothing);

    await tester.tap(find.byKey(const Key('sort-desktop-trigger')));
    await tester.pumpAndSettle();
    await tester.tap(_panelText('sort-desktop-panel', '升序'));
    await tester.pumpAndSettle();

    expect(selectedDirection, SortDirection.asc);
    expect(find.byKey(const Key('sort-desktop-panel')), findsNothing);
  });

  testWidgets('desktop sort can select the default option', (tester) async {
    int? selectedField;
    await pumpWithProviders(
      tester,
      home: Scaffold(
        body: Center(
          child: _DesktopSortHarness(
            onFieldChanged: (field) => selectedField = field,
            onDirectionChanged: (_) {},
          ),
        ),
      ),
      theme: buildSakuraDesktopThemeData(),
      physicalSize: const Size(1100, 700),
    );

    await tester.tap(find.byKey(const Key('sort-desktop-trigger')));
    await tester.pumpAndSettle();
    await tester.tap(_panelText('sort-desktop-panel', '手动'));
    await tester.pumpAndSettle();

    expect(selectedField, isNull);
    expect(find.byKey(const Key('sort-desktop-panel')), findsNothing);
  });

  testWidgets('icon-only mobile trigger opens glass sort drawer', (
    tester,
  ) async {
    int? selectedField;
    (int?, SortDirection)? directionChange;
    await pumpWithProviders(
      tester,
      home: Scaffold(
        body: Center(
          child: _SortHarness(
            onFieldChanged: (field) => selectedField = field,
            onDirectionChanged: (field, direction) =>
                directionChange = (field, direction),
          ),
        ),
      ),
      theme: sakuraMobileThemeData,
      physicalSize: const Size(390, 844),
    );

    await tester.tap(find.byKey(const Key('sort-icon-trigger')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('sort-icon-drawer')), findsOneWidget);
    expect(find.byType(AppSegmentedControl<SortDirection>), findsNothing);

    await tester.tap(find.text('入库时间'));
    await tester.pumpAndSettle();
    expect(selectedField, 1);
    expect(find.byKey(const Key('sort-icon-drawer')), findsOneWidget);
    expect(find.byKey(const Key('sort-field-control')), findsOneWidget);
    expect(
      tester
          .widget<AppSegmentedControl<int?>>(
            find.byType(AppSegmentedControl<int?>),
          )
          .selected,
      1,
    );
    expect(find.byType(AppSegmentedControl<SortDirection>), findsOneWidget);

    await tester.tap(find.text('升序'));
    await tester.pumpAndSettle();
    expect(directionChange, (1, SortDirection.asc));
    expect(find.byKey(const Key('sort-icon-drawer')), findsOneWidget);
    expect(find.byKey(const Key('sort-direction-control')), findsOneWidget);
    expect(
      tester
          .widget<AppSegmentedControl<SortDirection>>(
            find.byType(AppSegmentedControl<SortDirection>),
          )
          .selected,
      SortDirection.asc,
    );
  });
}

Finder _panelText(String panelKey, String text) {
  return find.descendant(
    of: find.byKey(Key(panelKey)),
    matching: find.text(text),
  );
}

class _SortHarness extends StatefulWidget {
  const _SortHarness({
    required this.onFieldChanged,
    required this.onDirectionChanged,
  });

  final ValueChanged<int?> onFieldChanged;
  final void Function(int? field, SortDirection direction) onDirectionChanged;

  @override
  State<_SortHarness> createState() => _SortHarnessState();
}

class _SortHarnessState extends State<_SortHarness> {
  int? _field;
  SortDirection _direction = SortDirection.desc;

  @override
  Widget build(BuildContext context) {
    final fieldAtBuild = _field;
    return AppSortMenuButton<int>(
      fields: const <int>[1, 2],
      selectedField: _field,
      fieldLabelBuilder: (field) => field == 1 ? '入库时间' : '标题',
      onFieldChanged: (field) {
        setState(() => _field = field);
        widget.onFieldChanged(field);
      },
      selectedDirection: _direction,
      onDirectionChanged: (direction) {
        widget.onDirectionChanged(fieldAtBuild, direction);
        setState(() => _direction = direction);
      },
      allowDefaultOption: true,
      defaultOptionLabel: '手动',
      directionVisibleWhen: (field) => field != null,
      useDrawer: true,
      iconOnly: true,
      triggerKey: const Key('sort-icon-trigger'),
      drawerKey: const Key('sort-icon-drawer'),
      fieldKeyBuilder: (field) => Key('sort-field-$field'),
      directionKeyBuilder: (direction) =>
          Key('sort-direction-${direction.name}'),
      fieldControlKey: const Key('sort-field-control'),
      directionControlKey: const Key('sort-direction-control'),
      tooltip: '排序',
    );
  }
}

class _DesktopSortHarness extends StatefulWidget {
  const _DesktopSortHarness({
    required this.onFieldChanged,
    required this.onDirectionChanged,
  });

  final ValueChanged<int?> onFieldChanged;
  final ValueChanged<SortDirection> onDirectionChanged;

  @override
  State<_DesktopSortHarness> createState() => _DesktopSortHarnessState();
}

class _DesktopSortHarnessState extends State<_DesktopSortHarness> {
  int? _field = 1;
  SortDirection _direction = SortDirection.desc;

  @override
  Widget build(BuildContext context) {
    return AppSortMenuButton<int>(
      fields: const <int>[1, 2],
      selectedField: _field,
      fieldLabelBuilder: (field) => field == 1 ? '入库时间' : '标题',
      onFieldChanged: (field) {
        setState(() => _field = field);
        widget.onFieldChanged(field);
      },
      selectedDirection: _direction,
      onDirectionChanged: (direction) {
        setState(() => _direction = direction);
        widget.onDirectionChanged(direction);
      },
      allowDefaultOption: true,
      defaultOptionLabel: '手动',
      directionVisibleWhen: (field) => field != null,
      triggerKey: const Key('sort-desktop-trigger'),
      panelKey: const Key('sort-desktop-panel'),
      fieldControlKey: const Key('sort-field-control'),
      directionControlKey: const Key('sort-direction-control'),
      tooltip: '排序',
    );
  }
}
