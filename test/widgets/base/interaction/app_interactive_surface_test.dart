import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/interaction/app_interactive_surface.dart';

import '../../../support/pump_with_providers.dart';

void main() {
  testWidgets('focused surface activates with Enter and Space', (tester) async {
    var taps = 0;
    final focusNode = FocusNode();
    addTearDown(focusNode.dispose);
    await pumpWithProviders(
      tester,
      home: Scaffold(
        body: Center(
          child: AppInteractiveSurface(
            key: const Key('focus-target'),
            focusNode: focusNode,
            onTap: () => taps++,
            child: const SizedBox(width: 120, height: 44),
          ),
        ),
      ),
      theme: sakuraDesktopThemeData,
    );

    focusNode.requestFocus();
    await tester.pump();

    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.sendKeyEvent(LogicalKeyboardKey.space);

    expect(taps, 2);
    expect(tester.takeException(), isNull);
  });
}
