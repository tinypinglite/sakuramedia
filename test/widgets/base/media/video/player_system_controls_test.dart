import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sakuramedia/widgets/base/media/video/player_system_controls.dart';

const MethodChannel _brightnessChannel = MethodChannel(
  'github.com/aaassseee/screen_brightness',
);
const MethodChannel _volumeChannel = MethodChannel(
  'com.kurenai7968.volume_controller.method',
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late List<MethodCall> brightnessCalls;
  late List<MethodCall> volumeCalls;
  late TestDefaultBinaryMessenger messenger;

  setUp(() {
    brightnessCalls = <MethodCall>[];
    volumeCalls = <MethodCall>[];
    messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(_brightnessChannel, (call) async {
      brightnessCalls.add(call);
      return switch (call.method) {
        'getApplicationScreenBrightness' => 0.35,
        _ => null,
      };
    });
    messenger.setMockMethodCallHandler(_volumeChannel, (call) async {
      volumeCalls.add(call);
      return switch (call.method) {
        'getVolume' => 0.65,
        _ => null,
      };
    });
  });

  tearDown(() {
    messenger.setMockMethodCallHandler(_brightnessChannel, null);
    messenger.setMockMethodCallHandler(_volumeChannel, null);
  });

  test('initialize reads current app brightness and media volume', () async {
    final controls = PlayerSystemControls();

    await controls.initialize();

    expect(controls.initialBrightness, 0.35);
    expect(controls.initialVolume, 0.65);
  });

  test('level writes are clamped and suppress the native volume HUD', () async {
    final controls = PlayerSystemControls();
    await controls.initialize();

    controls.setBrightness(1.4);
    controls.setVolume(-0.2);
    await Future<void>.delayed(Duration.zero);

    final brightnessWrite = brightnessCalls.singleWhere(
      (call) => call.method == 'setApplicationScreenBrightness',
    );
    final volumeWrite = volumeCalls.singleWhere(
      (call) => call.method == 'setVolume',
    );
    expect(
      (brightnessWrite.arguments as Map<Object?, Object?>)['brightness'],
      1.0,
    );
    expect((volumeWrite.arguments as Map<Object?, Object?>)['volume'], 0.0);
    expect(
      (volumeWrite.arguments as Map<Object?, Object?>)['showSystemUI'],
      isFalse,
    );
  });

  test(
    'reset restores app brightness only after brightness was changed',
    () async {
      final controls = PlayerSystemControls();
      await controls.initialize();

      await controls.resetBrightness();
      expect(
        brightnessCalls.where(
          (call) => call.method == 'resetApplicationScreenBrightness',
        ),
        isEmpty,
      );

      controls.setBrightness(0.8);
      await controls.resetBrightness();

      expect(
        brightnessCalls.where(
          (call) => call.method == 'resetApplicationScreenBrightness',
        ),
        hasLength(1),
      );
      expect(controls.initialBrightness, 0.35);
    },
  );

  test('platform failures fall back to 50 percent without escaping', () async {
    messenger.setMockMethodCallHandler(_brightnessChannel, (call) async {
      throw PlatformException(code: 'unavailable');
    });
    messenger.setMockMethodCallHandler(_volumeChannel, (call) async {
      throw PlatformException(code: 'unavailable');
    });
    final controls = PlayerSystemControls();

    await controls.initialize();
    expect(controls.initialBrightness, 0.5);
    expect(controls.initialVolume, 0.5);

    controls.setBrightness(0.7);
    controls.setVolume(0.8);
    await controls.resetBrightness();
  });
}
