import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/app_desktop_dialog.dart';

void main() {
  testWidgets('app desktop dialog applies width and height to content', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: sakuraThemeData,
        home: Builder(
          builder: (context) {
            return Scaffold(
              body: TextButton(
                onPressed: () {
                  showDialog<void>(
                    context: context,
                    builder:
                        (_) => const AppDesktopDialog(
                          dialogKey: Key('desktop-dialog'),
                          contentKey: Key('desktop-dialog-content'),
                          width: 480,
                          height: 320,
                          child: SizedBox.expand(
                            key: Key('desktop-dialog-inner'),
                          ),
                        ),
                  );
                },
                child: const Text('open'),
              ),
            );
          },
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('desktop-dialog')), findsOneWidget);
    expect(find.byType(Dialog), findsOneWidget);
    expect(
      tester.getSize(find.byKey(const Key('desktop-dialog-content'))),
      const Size(480, 320),
    );
    expect(
      tester.getSize(find.byKey(const Key('desktop-dialog-inner'))),
      const Size(432, 272),
    );
    expect(find.byTooltip('关闭'), findsOneWidget);
  });

  testWidgets('app desktop dialog close button dismisses the dialog', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: sakuraThemeData,
        home: Builder(
          builder: (context) {
            return Scaffold(
              body: TextButton(
                onPressed: () {
                  showDialog<void>(
                    context: context,
                    builder:
                        (_) => const AppDesktopDialog(
                          dialogKey: Key('desktop-dialog-dismissible'),
                          width: 320,
                          child: SizedBox(height: 120),
                        ),
                  );
                },
                child: const Text('open'),
              ),
            );
          },
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('desktop-dialog-dismissible')), findsOneWidget);
    await tester.tap(find.byTooltip('关闭'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('desktop-dialog-dismissible')), findsNothing);
  });
}
