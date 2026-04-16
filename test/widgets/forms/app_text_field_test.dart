import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/forms/app_text_field.dart';

void main() {
  testWidgets('renders label helper prefix suffix and forwards changes', (
    WidgetTester tester,
  ) async {
    var latestValue = '';

    await tester.pumpWidget(
      MaterialApp(
        theme: sakuraThemeData,
        home: Material(
          child: AppTextField(
            fieldKey: const Key('app-text-field'),
            label: '名称',
            helperText: '辅助信息',
            hintText: '请输入名称',
            prefix: const Icon(Icons.search_rounded),
            suffix: const Icon(Icons.clear_rounded),
            onChanged: (value) => latestValue = value,
          ),
        ),
      ),
    );

    expect(find.text('名称'), findsOneWidget);
    expect(find.text('辅助信息'), findsOneWidget);
    expect(find.byIcon(Icons.search_rounded), findsOneWidget);
    expect(find.byIcon(Icons.clear_rounded), findsOneWidget);

    await tester.enterText(find.byKey(const Key('app-text-field')), 'jackett');

    expect(latestValue, 'jackett');
  });

  testWidgets('supports obscure text and disabled state', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: sakuraThemeData,
        home: const Material(
          child: AppTextField(
            fieldKey: Key('password-field'),
            obscureText: true,
            enabled: false,
          ),
        ),
      ),
    );

    final editableText = tester.widget<EditableText>(
      find.descendant(
        of: find.byKey(const Key('password-field')),
        matching: find.byType(EditableText),
      ),
    );
    final textFormField = tester.widget<TextFormField>(
      find.byType(TextFormField),
    );

    expect(editableText.obscureText, isTrue);
    expect(textFormField.enabled, isFalse);
  });

  testWidgets('keeps focused border color same as enabled border', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: sakuraThemeData,
        home: Material(
          child: Form(
            child: AppTextField(
              fieldKey: const Key('validated-field'),
              validator: (_) => '请输入内容',
              autovalidateMode: AutovalidateMode.always,
            ),
          ),
        ),
      ),
    );

    final decoration =
        tester.widget<InputDecorator>(find.byType(InputDecorator)).decoration;
    final enabledBorder = decoration.enabledBorder! as OutlineInputBorder;
    final focusedBorder = decoration.focusedBorder! as OutlineInputBorder;
    final errorBorder = decoration.errorBorder! as OutlineInputBorder;

    expect(enabledBorder.borderSide.color, focusedBorder.borderSide.color);
    expect(enabledBorder.borderRadius, sakuraThemeData.appRadius.smBorder);
    expect(errorBorder.borderSide.color, sakuraThemeData.colorScheme.error);
    expect(find.text('请输入内容'), findsOneWidget);
  });

  testWidgets('uses form tokens for label gap and content padding', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: sakuraThemeData,
        home: const Material(
          child: AppTextField(
            fieldKey: Key('sized-field'),
            label: '名称',
            hintText: '请输入名称',
          ),
        ),
      ),
    );

    final sizedBox = tester.widget<SizedBox>(
      find.byWidgetPredicate(
        (widget) =>
            widget is SizedBox &&
            widget.height == sakuraThemeData.appFormTokens.labelGap,
      ),
    );
    final decoration =
        tester.widget<InputDecorator>(find.byType(InputDecorator)).decoration;

    expect(sizedBox.height, sakuraThemeData.appFormTokens.labelGap);
    expect(
      decoration.contentPadding,
      EdgeInsets.symmetric(
        horizontal: sakuraThemeData.appFormTokens.fieldHorizontalPadding,
        vertical: sakuraThemeData.appFormTokens.fieldVerticalPadding,
      ),
    );
  });
}
