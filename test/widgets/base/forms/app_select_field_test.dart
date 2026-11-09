import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/forms/app_select_field.dart';
import 'package:sakuramedia/widgets/base/layout/surface/app_surface.dart';

import '../../../support/pump_with_providers.dart';

void main() {
  testWidgets('selects a value and closes the menu', (tester) async {
    var value = 1;
    await _pumpField(tester, onChanged: (next) => value = next!);

    await tester.tap(find.text('选项 A'));
    await tester.pumpAndSettle();
    expect(find.text('选项 B'), findsWidgets);

    await tester.tap(find.text('选项 B').last);
    await tester.pumpAndSettle();
    expect(value, 2);
  });

  testWidgets('disabled field does not open the menu', (tester) async {
    await _pumpField(tester, onChanged: null);

    await tester.tap(find.text('选项 A'));
    await tester.pumpAndSettle();
    expect(find.text('选项 B'), findsNothing);
  });

  testWidgets('validation error remains visible with flat surface', (
    tester,
  ) async {
    final formKey = GlobalKey<FormState>();
    await _pumpField(
      tester,
      formKey: formKey,
      onChanged: (_) {},
      validator: (_) => '请选择',
      flat: true,
    );

    expect(formKey.currentState!.validate(), isFalse);
    await tester.pump();
    expect(find.text('请选择'), findsOneWidget);
  });
}

Future<void> _pumpField(
  WidgetTester tester, {
  required ValueChanged<int?>? onChanged,
  Key? formKey,
  FormFieldValidator<int>? validator,
  bool flat = false,
}) async {
  final formStateKey = formKey as GlobalKey<FormState>?;
  await pumpWithProviders(
    tester,
    theme: sakuraDesktopThemeData,
    wrap: (child) => AppSurfaceStyleScope(
      style: flat ? AppSurfaceStyle.flat : AppSurfaceStyle.liquid,
      child: child,
    ),
    home: Form(
      key: formStateKey,
      child: Scaffold(
        body: Padding(
          padding: const EdgeInsets.all(24),
          child: AppSelectField<int>(
            key: const Key('select-field'),
            value: 1,
            label: '选择',
            items: const <DropdownMenuItem<int>>[
              DropdownMenuItem(value: 1, child: Text('选项 A')),
              DropdownMenuItem(value: 2, child: Text('选项 B')),
            ],
            validator: validator,
            onChanged: onChanged,
          ),
        ),
      ),
    ),
  );
}
