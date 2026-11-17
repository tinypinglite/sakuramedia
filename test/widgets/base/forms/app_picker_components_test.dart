import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/forms/app_picker_header.dart';
import 'package:sakuramedia/widgets/base/forms/app_picker_layout.dart';

import '../../../support/pump_with_providers.dart';

void main() {
  testWidgets('picker row forwards taps', (tester) async {
    var taps = 0;
    const optionKey = Key('picker-option');
    await pumpWithProviders(
      tester,
      home: Scaffold(
        body: AppPickerIosSection(
          children: [
            AppPickerIosRow(
              selected: true,
              showCheckmark: true,
              onTap: () => taps++,
              title: '收藏',
              optionKey: optionKey,
            ),
          ],
        ),
      ),
      theme: sakuraThemeData,
      physicalSize: const Size(600, 400),
    );

    await tester.tap(find.byKey(optionKey));
    await tester.pump();
    expect(taps, 1);
  });

  testWidgets('busy picker row does not forward taps', (tester) async {
    var taps = 0;
    const optionKey = Key('picker-option');
    await pumpWithProviders(
      tester,
      home: Scaffold(
        body: AppPickerIosSection(
          children: [
            AppPickerIosRow(
              selected: false,
              busy: true,
              busyKey: const Key('picker-busy'),
              onTap: () => taps++,
              title: '收藏',
              optionKey: optionKey,
            ),
          ],
        ),
      ),
      theme: sakuraThemeData,
      physicalSize: const Size(600, 400),
    );

    await tester.tap(find.byKey(optionKey), warnIfMissed: false);
    await tester.pump();
    expect(taps, 0);
    expect(find.byKey(const Key('picker-busy')), findsOneWidget);
  });

  testWidgets('picker header forwards done action', (tester) async {
    var dones = 0;
    await pumpWithProviders(
      tester,
      home: Scaffold(
        body: AppPickerHeader(
          title: '加入播放列表',
          onDone: () => dones++,
          doneKey: const Key('picker-done'),
        ),
      ),
      theme: sakuraThemeData,
      physicalSize: const Size(600, 400),
    );

    await tester.tap(find.byKey(const Key('picker-done')));
    await tester.pump();
    expect(dones, 1);
  });

  testWidgets('picker header search forwards changes and clears', (
    tester,
  ) async {
    final controller = TextEditingController(text: '精选');
    addTearDown(controller.dispose);
    final changes = <String>[];
    await pumpWithProviders(
      tester,
      home: Scaffold(
        body: AppPickerHeader(
          title: '选择合集',
          searchController: controller,
          searchFieldKey: const Key('picker-search'),
          clearSearchKey: const Key('picker-search-clear'),
          onSearchChanged: changes.add,
        ),
      ),
      theme: sakuraThemeData,
      physicalSize: const Size(600, 400),
    );

    await tester.enterText(find.byKey(const Key('picker-search')), '周末');
    await tester.pump();
    expect(controller.text, '周末');
    expect(changes, contains('周末'));

    await tester.tap(find.byKey(const Key('picker-search-clear')));
    await tester.pump();
    expect(controller.text, isEmpty);
    expect(changes.last, isEmpty);
  });

  testWidgets('titleless picker header keeps search usable', (tester) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);
    final changes = <String>[];
    await pumpWithProviders(
      tester,
      home: Scaffold(
        body: AppPickerHeader(
          searchController: controller,
          searchFieldKey: const Key('picker-search'),
          clearSearchKey: const Key('picker-search-clear'),
          onSearchChanged: changes.add,
        ),
      ),
      theme: sakuraThemeData,
      physicalSize: const Size(600, 400),
    );

    await tester.enterText(find.byKey(const Key('picker-search')), 'Alpha');
    await tester.pump();

    expect(controller.text, 'Alpha');
    expect(changes, contains('Alpha'));
    expect(tester.takeException(), isNull);
  });
}
