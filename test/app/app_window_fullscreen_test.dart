import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sakuramedia/app/app_window_fullscreen.dart';

/// macOS / Windows 都走原生 `setFullScreen`（窗口是非无边框的，
/// `TitleBarStyle.hidden` 只藏标题栏）；这组单测锁住平台分支。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('window_manager');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  final previousPlatformOverride = debugDefaultTargetPlatformOverride;
  final calls = <MethodCall>[];

  setUp(() {
    calls.clear();
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      return null;
    });
  });

  tearDown(() {
    debugDefaultTargetPlatformOverride = previousPlatformOverride;
    messenger.setMockMethodCallHandler(channel, null);
  });

  test('windows uses native fullscreen', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    calls.clear();

    await applyDesktopWindowFullscreen(true);

    expect(calls.map((call) => call.method), <String>['setFullScreen']);
    expect(calls.single.arguments, <String, Object?>{'isFullScreen': true});

    calls.clear();
    await applyDesktopWindowFullscreen(false);

    expect(calls.map((call) => call.method), <String>['setFullScreen']);
    expect(calls.single.arguments, <String, Object?>{'isFullScreen': false});
  });

  test('macOS keeps window_manager fullscreen', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    calls.clear();

    await applyDesktopWindowFullscreen(true);

    expect(calls.map((call) => call.method), <String>['setFullScreen']);
    expect(calls.single.arguments, <String, Object?>{'isFullScreen': true});
  });

  test('mobile platforms only switch the in-app layout', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    calls.clear();

    await applyDesktopWindowFullscreen(true);

    expect(calls, isEmpty);
  });
}
