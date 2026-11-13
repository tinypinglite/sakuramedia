import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sakuramedia/widgets/base/media/video/player_screen_orientation.dart';
import 'package:sakuramedia/widgets/domain/movies/player/landscape_player_system_ui.dart';

const MethodChannel _immersiveChannel = MethodChannel(
  'sakuramedia/immersive_system_ui',
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late List<MethodCall> systemCalls;
  late List<MethodCall> immersiveCalls;
  late TestDefaultBinaryMessenger messenger;

  setUp(() {
    systemCalls = <MethodCall>[];
    immersiveCalls = <MethodCall>[];
    messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      systemCalls.add(call);
      return null;
    });
    messenger.setMockMethodCallHandler(_immersiveChannel, (call) async {
      immersiveCalls.add(call);
      return null;
    });
  });

  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    messenger.setMockMethodCallHandler(SystemChannels.platform, null);
    messenger.setMockMethodCallHandler(_immersiveChannel, null);
  });

  MethodCall systemCallFor(String method) =>
      systemCalls.singleWhere((call) => call.method == method);

  group('Android', () {
    setUp(() {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
    });

    test('播放页进入锁横屏并通过原生通道隐藏系统栏', () async {
      await enterLandscapePlayerSystemUi();

      expect(immersiveCalls, hasLength(1));
      expect(immersiveCalls.single.method, 'setImmersive');
      expect(immersiveCalls.single.arguments, <String, bool>{'enabled': true});
      expect(
        systemCallFor('SystemChrome.setPreferredOrientations').arguments,
        <String>[
          'DeviceOrientation.landscapeLeft',
          'DeviceOrientation.landscapeRight',
        ],
      );
      expect(
        systemCalls.where(
          (call) => call.method == 'SystemChrome.setEnabledSystemUIMode',
        ),
        isEmpty,
      );
    });

    test('播放页退出恢复系统栏并解除方向锁定', () async {
      await restoreSystemUiAfterLandscapePlayer();

      expect(immersiveCalls, hasLength(1));
      expect(immersiveCalls.single.arguments, <String, bool>{'enabled': false});
      expect(
        systemCallFor('SystemChrome.setPreferredOrientations').arguments,
        isEmpty,
      );
    });

    test('media_kit 全屏进出只改方向，不重复切换系统栏', () async {
      await enterPlayerFullscreenOrientation();
      await lockPlayerPageLandscape();

      expect(immersiveCalls, isEmpty);
      final orientationCalls = systemCalls
          .where(
            (call) => call.method == 'SystemChrome.setPreferredOrientations',
          )
          .toList();
      expect(orientationCalls, hasLength(2));
      expect(orientationCalls[0].arguments, <String>[
        'DeviceOrientation.portraitUp',
        'DeviceOrientation.landscapeLeft',
        'DeviceOrientation.landscapeRight',
      ]);
      expect(orientationCalls[1].arguments, <String>[
        'DeviceOrientation.landscapeLeft',
        'DeviceOrientation.landscapeRight',
      ]);
    });
  });

  group('iOS', () {
    setUp(() {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    });

    test('播放页进入使用 SystemChrome 进入沉浸并锁横屏', () async {
      await enterLandscapePlayerSystemUi();

      expect(immersiveCalls, isEmpty);
      expect(
        systemCallFor('SystemChrome.setEnabledSystemUIMode').arguments,
        'SystemUiMode.immersiveSticky',
      );
      expect(
        systemCallFor('SystemChrome.setPreferredOrientations').arguments,
        <String>[
          'DeviceOrientation.landscapeLeft',
          'DeviceOrientation.landscapeRight',
        ],
      );
    });

    test('播放页退出通过 SystemChrome 恢复系统栏并解除方向锁定', () async {
      await restoreSystemUiAfterLandscapePlayer();

      expect(immersiveCalls, isEmpty);
      expect(
        systemCallFor('SystemChrome.setEnabledSystemUIOverlays').arguments,
        containsAll(<String>['SystemUiOverlay.top', 'SystemUiOverlay.bottom']),
      );
      expect(
        systemCallFor('SystemChrome.setPreferredOrientations').arguments,
        isEmpty,
      );
    });
  });
}
