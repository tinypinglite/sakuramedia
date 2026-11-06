import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/forms/app_glass_search_field.dart';

import '../../../support/pump_with_providers.dart';

void main() {
  testWidgets('输入透传并在清空时回传空字符串', (tester) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);
    final changes = <String>[];

    await pumpWithProviders(
      tester,
      home: Scaffold(
        body: Padding(
          padding: const EdgeInsets.all(24),
          child: AppGlassSearchField(
            fieldKey: const Key('glass-search-field'),
            clearKey: const Key('glass-search-clear'),
            controller: controller,
            hintText: '搜索合集',
            onChanged: changes.add,
          ),
        ),
      ),
      theme: sakuraDesktopThemeData,
      physicalSize: const Size(600, 400),
    );

    await tester.enterText(find.byKey(const Key('glass-search-field')), '精选');
    await tester.pump();
    expect(controller.text, '精选');
    expect(changes, contains('精选'));

    await tester.tap(find.byKey(const Key('glass-search-clear')));
    await tester.pump();
    expect(controller.text, isEmpty);
    expect(changes.last, isEmpty);
  });
}
