import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/media/preview_dialog_surface.dart';

void main() {
  testWidgets('preview dialog surface applies width and height to content', (
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
                        (_) => const PreviewDialogSurface(
                          dialogKey: Key('preview-dialog'),
                          contentKey: Key('preview-dialog-content'),
                          width: 480,
                          height: 320,
                          child: SizedBox.expand(),
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

    expect(find.byKey(const Key('preview-dialog')), findsOneWidget);
    expect(find.byType(Dialog), findsOneWidget);
    expect(
      tester.getSize(find.byKey(const Key('preview-dialog-content'))),
      const Size(480, 320),
    );
  });

  testWidgets('preview dialog surface applies custom constraints', (
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
                        (_) => const PreviewDialogSurface(
                          contentKey: Key('preview-dialog-constrained-content'),
                          constraints: BoxConstraints(
                            maxWidth: 420,
                            maxHeight: 260,
                          ),
                          child: SizedBox.expand(),
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

    expect(
      tester.getSize(
        find.byKey(const Key('preview-dialog-constrained-content')),
      ),
      const Size(420, 260),
    );
  });
}
