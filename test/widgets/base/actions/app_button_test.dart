import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/actions/app_button.dart';
import 'package:sakuramedia/widgets/base/actions/app_text_button.dart';

import '../../../support/pump_with_providers.dart';

void main() {
  testWidgets('button hugs its content inside Align', (tester) async {
    const buttonKey = Key('hugging-button');
    await pumpWithProviders(
      tester,
      home: Scaffold(
        body: SizedBox(
          width: 600,
          child: Align(
            alignment: Alignment.centerRight,
            child: AppButton(
              key: buttonKey,
              label: '保存',
              onPressed: () {},
            ),
          ),
        ),
      ),
      theme: sakuraDesktopThemeData,
      physicalSize: const Size(800, 400),
    );

    // 右对齐的次级动作应保持自然宽度；父级宽度是 600。
    expect(tester.getSize(find.byKey(buttonKey)).width, lessThan(200));
  });

  testWidgets('button fills tight parent constraints', (tester) async {
    const buttonKey = Key('full-width-button');
    await pumpWithProviders(
      tester,
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: 240,
            child: AppButton(
              key: buttonKey,
              label: '保存',
              onPressed: () {},
            ),
          ),
        ),
      ),
      theme: sakuraDesktopThemeData,
      physicalSize: const Size(800, 400),
    );

    expect(tester.getSize(find.byKey(buttonKey)).width, greaterThan(200));
  });

  testWidgets('loading button keeps the label and ignores taps', (tester) async {
    const buttonKey = Key('loading-button');
    var taps = 0;
    await pumpWithProviders(
      tester,
      home: Scaffold(
        body: AppButton(
          key: buttonKey,
          label: '保存',
          isLoading: true,
          onPressed: () => taps++,
        ),
      ),
      theme: sakuraDesktopThemeData,
      physicalSize: const Size(400, 200),
    );

    expect(find.text('保存'), findsOneWidget);
    await tester.tap(find.byKey(buttonKey));
    await tester.pump();
    expect(taps, 0);
  });

  testWidgets('disabled buttons ignore taps', (tester) async {
    await pumpWithProviders(
      tester,
      home: Scaffold(
        body: Column(
          children: [
            AppButton(
              key: const Key('disabled-button'),
              label: '禁用',
              onPressed: null,
            ),
            AppTextButton(
              key: const Key('disabled-text-button'),
              label: '禁用文字',
              onPressed: null,
            ),
          ],
        ),
      ),
      theme: sakuraDesktopThemeData,
      physicalSize: const Size(400, 200),
    );

    await tester.tap(find.byKey(const Key('disabled-button')));
    await tester.tap(find.byKey(const Key('disabled-text-button')));
    await tester.pump();
    expect(tester.takeException(), isNull);
  });
}
