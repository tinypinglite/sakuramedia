import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sakuramedia/core/platform/immersive_system_ui.dart';

const MethodChannel _immersiveChannel = MethodChannel(
  'sakuramedia/immersive_system_ui',
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late List<MethodCall> nativeCalls;
  late List<MethodCall> systemCalls;
  late TestDefaultBinaryMessenger messenger;

  setUp(() {
    nativeCalls = <MethodCall>[];
    systemCalls = <MethodCall>[];
    messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(_immersiveChannel, (call) async {
      nativeCalls.add(call);
      return null;
    });
    messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      systemCalls.add(call);
      return null;
    });
  });

  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    messenger.setMockMethodCallHandler(_immersiveChannel, null);
    messenger.setMockMethodCallHandler(SystemChannels.platform, null);
  });

  test('Android uses the native immersive channel', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;

    await setImmersiveSystemUi(enabled: true);

    expect(nativeCalls, hasLength(1));
    expect(nativeCalls.single.method, 'setImmersive');
    expect(nativeCalls.single.arguments, <String, bool>{'enabled': true});
    expect(systemCalls, isEmpty);
  });

  test(
    'Android falls back to SystemChrome when the native channel fails',
    () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      messenger.setMockMethodCallHandler(_immersiveChannel, (call) async {
        throw PlatformException(code: 'unavailable');
      });

      await setImmersiveSystemUi(enabled: false);

      final call = systemCalls.singleWhere(
        (call) => call.method == 'SystemChrome.setEnabledSystemUIOverlays',
      );
      expect(
        call.arguments,
        containsAll(<String>['SystemUiOverlay.top', 'SystemUiOverlay.bottom']),
      );
    },
  );

  test('iOS uses SystemChrome without the native channel', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;

    await setImmersiveSystemUi(enabled: true);
    await setImmersiveSystemUi(enabled: false);

    expect(nativeCalls, isEmpty);
    final immersiveCall = systemCalls.singleWhere(
      (call) => call.method == 'SystemChrome.setEnabledSystemUIMode',
    );
    expect(immersiveCall.arguments, 'SystemUiMode.immersiveSticky');
    final restoreCall = systemCalls.singleWhere(
      (call) => call.method == 'SystemChrome.setEnabledSystemUIOverlays',
    );
    expect(
      restoreCall.arguments,
      containsAll(<String>['SystemUiOverlay.top', 'SystemUiOverlay.bottom']),
    );
  });
}
