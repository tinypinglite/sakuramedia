import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sakuramedia/core/platform/haptic_feedback.dart';

void main() {
  testWidgets('triggerSelectionHaptic 向平台发送 selectionClick', (
    WidgetTester tester,
  ) async {
    final calls = <MethodCall>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (MethodCall call) async {
        calls.add(call);
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );

    await tester.runAsync(() async {
      triggerSelectionHaptic();
      await Future<void>.delayed(Duration.zero);
    });

    expect(
      calls.map((call) => '${call.method}:${call.arguments}'),
      contains('HapticFeedback.vibrate:HapticFeedbackType.selectionClick'),
    );
  });
}
