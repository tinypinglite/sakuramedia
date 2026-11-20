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

  testWidgets('focused surface activates with D-pad select', (tester) async {
    var taps = 0;
    final focusNode = FocusNode();
    addTearDown(focusNode.dispose);
    await pumpWithProviders(
      tester,
      home: Scaffold(
        body: Center(
          child: AppInteractiveSurface(
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

    await tester.sendKeyEvent(LogicalKeyboardKey.select);

    expect(taps, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('d-pad traversal keeps focused surfaces visible', (tester) async {
    final scrollController = ScrollController();
    addTearDown(scrollController.dispose);
    final focusNodes = List<FocusNode>.generate(
      8,
      (index) => FocusNode(debugLabel: 'surface-$index'),
    );
    addTearDown(() {
      for (final node in focusNodes) {
        node.dispose();
      }
    });

    await pumpWithProviders(
      tester,
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: 300,
            height: 100,
            child: ListView.builder(
              controller: scrollController,
              scrollDirection: Axis.horizontal,
              itemCount: focusNodes.length,
              itemBuilder: (context, index) => SizedBox(
                width: 200,
                child: AppInteractiveSurface(
                  focusNode: focusNodes[index],
                  onTap: () {},
                  child: const SizedBox.expand(),
                ),
              ),
            ),
          ),
        ),
      ),
      theme: buildSakuraTvThemeData(),
      physicalSize: const Size(800, 400),
    );

    focusNodes.first.requestFocus();
    await tester.pump();
    for (var index = 0; index < 3; index++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pumpAndSettle();
    }

    expect(focusNodes[3].hasFocus, isTrue);
    expect(scrollController.offset, greaterThan(0));
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
