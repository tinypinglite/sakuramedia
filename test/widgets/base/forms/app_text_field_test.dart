import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/forms/app_text_field.dart';

import '../../../support/pump_with_providers.dart';

void main() {
  testWidgets('validates controller text and clears the error after editing', (
    tester,
  ) async {
    final formKey = GlobalKey<FormState>();
    final controller = TextEditingController();
    addTearDown(controller.dispose);
    final changes = <String>[];

    await pumpWithProviders(
      tester,
      home: Scaffold(
        body: Form(
          key: formKey,
          child: AppTextField(
            fieldKey: const Key('app-text-field'),
            controller: controller,
            validator: (value) =>
                value == null || value.trim().isEmpty ? '必填' : null,
            onChanged: changes.add,
          ),
        ),
      ),
      theme: sakuraThemeData,
      physicalSize: const Size(600, 400),
    );

    expect(formKey.currentState!.validate(), isFalse);
    await tester.pump();
    expect(find.text('必填'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('app-text-field')), '玻璃输入');
    await tester.pump();

    expect(controller.text, '玻璃输入');
    expect(changes, contains('玻璃输入'));
    expect(formKey.currentState!.validate(), isTrue);
    await tester.pump();
    expect(find.text('必填'), findsNothing);
  });

  testWidgets('external controller updates are included in validation', (
    tester,
  ) async {
    final formKey = GlobalKey<FormState>();
    final controller = TextEditingController();
    addTearDown(controller.dispose);

    await pumpWithProviders(
      tester,
      home: Scaffold(
        body: Form(
          key: formKey,
          child: AppTextField(
            fieldKey: const Key('app-text-field'),
            controller: controller,
            validator: (value) =>
                value == null || value.trim().isEmpty ? '必填' : null,
          ),
        ),
      ),
      theme: sakuraThemeData,
      physicalSize: const Size(600, 400),
    );

    expect(formKey.currentState!.validate(), isFalse);
    controller.text = '外部写入';
    await tester.pump();
    expect(formKey.currentState!.validate(), isTrue);
  });

  testWidgets('multiline input keeps line breaks', (tester) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);

    await pumpWithProviders(
      tester,
      home: Scaffold(
        body: AppTextField(
          fieldKey: const Key('app-text-field'),
          controller: controller,
          minLines: 2,
          maxLines: 3,
        ),
      ),
      theme: sakuraThemeData,
      physicalSize: const Size(600, 400),
    );

    await tester.enterText(find.byKey(const Key('app-text-field')), 'AA\nBB');
    await tester.pump();
    expect(controller.text, 'AA\nBB');
  });

  testWidgets('fillColor keeps the field usable', (tester) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);

    await pumpWithProviders(
      tester,
      home: Scaffold(
        body: AppTextField(
          fieldKey: const Key('app-text-field'),
          controller: controller,
          fillColor: const Color(0x33FFFFFF),
        ),
      ),
      theme: sakuraThemeData,
      physicalSize: const Size(600, 400),
    );

    await tester.enterText(find.byKey(const Key('app-text-field')), '填充色');
    await tester.pump();
    expect(controller.text, '填充色');
  });
}
