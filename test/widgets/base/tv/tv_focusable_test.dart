import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/tv/tv_focusable.dart';

void main() {
  testWidgets('D-pad select activates a TV focusable', (tester) async {
    var presses = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: sakuraDesktopThemeData,
        home: Scaffold(
          body: Center(
            child: TvFocusable(
              autofocus: true,
              onPressed: () => presses++,
              child: const SizedBox(width: 120, height: 64),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    await tester.sendKeyEvent(LogicalKeyboardKey.select);

    expect(presses, 1);
  });
}
