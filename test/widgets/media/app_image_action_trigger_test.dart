import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sakuramedia/widgets/media/app_image_action_trigger.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('image action trigger forwards primary tap unchanged', (
    WidgetTester tester,
  ) async {
    var tapped = false;
    Offset? menuPosition;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AppImageActionTrigger(
            onTap: () => tapped = true,
            onRequestMenu: (position) => menuPosition = position,
            child: const SizedBox(width: 100, height: 100),
          ),
        ),
      ),
    );

    await tester.tap(find.byType(AppImageActionTrigger));
    await tester.pump();

    expect(tapped, isTrue);
    expect(menuPosition, isNull);
  });

  testWidgets('image action trigger opens menu on long press start', (
    WidgetTester tester,
  ) async {
    Offset? menuPosition;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AppImageActionTrigger(
            onRequestMenu: (position) => menuPosition = position,
            child: const SizedBox(width: 100, height: 100),
          ),
        ),
      ),
    );

    final center = tester.getCenter(find.byType(AppImageActionTrigger));
    final gesture = await tester.startGesture(center);
    await tester.pump(kLongPressTimeout);
    await gesture.up();

    expect(menuPosition, isNotNull);
    expect(menuPosition, equals(center));
  });

  testWidgets('image action trigger opens menu on secondary tap', (
    WidgetTester tester,
  ) async {
    Offset? menuPosition;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AppImageActionTrigger(
            onRequestMenu: (position) => menuPosition = position,
            child: const SizedBox(width: 100, height: 100),
          ),
        ),
      ),
    );

    final center = tester.getCenter(find.byType(AppImageActionTrigger));
    await tester.tapAt(center, buttons: kSecondaryMouseButton);
    await tester.pump();

    expect(menuPosition, isNotNull);
    expect(menuPosition, equals(center));
  });
}
