import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/actions/app_button.dart';
import 'package:sakuramedia/widgets/sheets/app_mobile_confirm_actions.dart';

void main() {
  Widget wrap(Widget child) {
    return MaterialApp(
      theme: sakuraThemeData,
      home: Scaffold(body: Padding(padding: const EdgeInsets.all(16), child: child)),
    );
  }

  testWidgets('renders default labels and triggers callbacks', (tester) async {
    var cancels = 0;
    var confirms = 0;
    await tester.pumpWidget(
      wrap(
        AppMobileConfirmActions(
          onCancel: () => cancels += 1,
          onConfirm: () => confirms += 1,
          cancelKey: const Key('cancel'),
          confirmKey: const Key('confirm'),
        ),
      ),
    );

    expect(find.text('取消'), findsOneWidget);
    expect(find.text('确认'), findsOneWidget);

    await tester.tap(find.byKey(const Key('cancel')));
    await tester.tap(find.byKey(const Key('confirm')));
    await tester.pumpAndSettle();

    expect(cancels, 1);
    expect(confirms, 1);
  });

  testWidgets('honors custom labels', (tester) async {
    await tester.pumpWidget(
      wrap(
        AppMobileConfirmActions(
          onCancel: () {},
          onConfirm: () {},
          cancelLabel: '保留',
          confirmLabel: '删除',
        ),
      ),
    );

    expect(find.text('保留'), findsOneWidget);
    expect(find.text('删除'), findsOneWidget);
  });

  testWidgets('switches confirm variant on isDangerous', (tester) async {
    await tester.pumpWidget(
      wrap(
        AppMobileConfirmActions(
          onCancel: () {},
          onConfirm: () {},
          confirmLabel: '删除',
          isDangerous: true,
          confirmKey: const Key('confirm'),
        ),
      ),
    );

    final confirmButton = tester.widget<AppButton>(find.byKey(const Key('confirm')));
    expect(confirmButton.variant, AppButtonVariant.danger);
  });

  testWidgets('isLoading disables cancel and shows spinner on confirm', (tester) async {
    var cancels = 0;
    await tester.pumpWidget(
      wrap(
        AppMobileConfirmActions(
          onCancel: () => cancels += 1,
          onConfirm: () {},
          isLoading: true,
          cancelKey: const Key('cancel'),
          confirmKey: const Key('confirm'),
        ),
      ),
    );

    final cancelButton = tester.widget<AppButton>(find.byKey(const Key('cancel')));
    expect(cancelButton.onPressed, isNull);

    final confirmButton = tester.widget<AppButton>(find.byKey(const Key('confirm')));
    expect(confirmButton.isLoading, isTrue);

    await tester.tap(find.byKey(const Key('cancel')));
    await tester.pump();
    expect(cancels, 0);
  });
}
