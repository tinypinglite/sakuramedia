import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sakuramedia/app/window_bootstrap_desktop.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('sakuramedia/window_appearance');

  test('macOS 同步窗口毛玻璃与不透明背景', () async {
    final previousOverride = debugDefaultTargetPlatformOverride;
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    try {
      final calls = <MethodCall>[];
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(channel, (call) async {
        calls.add(call);
        return null;
      });
      addTearDown(() => messenger.setMockMethodCallHandler(channel, null));

      await applyDesktopWindowAppearance(
        brightness: Brightness.dark,
        windowVibrancy: false,
      );

      expect(calls, hasLength(1));
      expect(calls.single.method, 'setAppearance');
      final arguments = calls.single.arguments as Map<Object?, Object?>;
      expect(arguments['dark'], isTrue);
      expect(arguments['windowVibrancy'], isFalse);
      expect(arguments['backgroundColor'], isA<int>());
    } finally {
      debugDefaultTargetPlatformOverride = previousOverride;
    }
  });
}
