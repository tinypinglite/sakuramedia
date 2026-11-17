import 'package:flutter/gestures.dart';
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

  testWidgets('reports mouse hover enter and exit', (tester) async {
    final hoverStates = <bool>[];
    await pumpWithProviders(
      tester,
      home: Scaffold(
        body: Center(
          child: AppInteractiveSurface(
            key: const Key('hover-target'),
            onTap: () {},
            onHoverChanged: hoverStates.add,
            child: const SizedBox(width: 120, height: 44),
          ),
        ),
      ),
      theme: sakuraDesktopThemeData,
    );

    final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
    addTearDown(gesture.removePointer);
    await gesture.addPointer(location: Offset.zero);
    await tester.pump();
    await gesture.moveTo(
      tester.getCenter(find.byKey(const Key('hover-target'))),
    );
    await tester.pump();
    await gesture.moveTo(const Offset(1, 1));
    await tester.pump();

    expect(hoverStates, <bool>[true, false]);
    expect(tester.takeException(), isNull);
  });
}
