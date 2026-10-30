import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/l10n/app_localizations.dart';
import 'package:flutter/services.dart';
import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:flutter_test/flutter_test.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:sakuramedia/widgets/base/media/video/player_screen_orientation.dart';
import 'package:sakuramedia/widgets/base/media/video/themed_video_player.dart';

import '../../../../support/test_playlist_player.dart';

class _FakeVideoController extends Fake implements VideoController {
  _FakeVideoController(this.player);

  @override
  final Player player;

  @override
  final notifier = ValueNotifier<PlatformVideoController?>(null);

  @override
  Future<void> get waitUntilFirstFrameRendered => Future.value();
}

/// 测试树的本地化 delegate：ARB 文案 + material_ui 的 Material/Cupertino 文案。
const List<LocalizationsDelegate<dynamic>> _testLocalizationsDelegates =
    <LocalizationsDelegate<dynamic>>[
      AppLocalizations.delegate,
      ...GlobalMaterialLocalizations.delegates,
    ];

void main() {
  Future<void> pumpPlayer(
    WidgetTester tester, {
    required bool useTouchOptimizedControls,
    bool displaySeekBar = true,
    List<Widget> bottomControls = const <Widget>[],
  }) async {
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('com.alexmercerind/media_kit_video'),
      (_) async => null,
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        const MethodChannel('com.alexmercerind/media_kit_video'),
        null,
      ),
    );
    final player = Player(platformPlayer: TestPlaylistPlayer());
    addTearDown(player.dispose);
    final controller = _FakeVideoController(player);
    addTearDown(controller.notifier.dispose);
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('zh'),
        localizationsDelegates: _testLocalizationsDelegates,
        supportedLocales: const <Locale>[Locale('zh'), Locale('en')],
        home: ThemedVideoPlayer(
          videoController: controller,
          useTouchOptimizedControls: useTouchOptimizedControls,
          displaySeekBar: displaySeekBar,
          bottomControls: bottomControls,
        ),
      ),
    );
  }

  testWidgets('移动端全屏接管方向：进入跟随传感器、退出回页面横屏', (tester) async {
    await pumpPlayer(tester, useTouchOptimizedControls: true);

    final video = tester.widget<Video>(find.byType(Video));
    expect(video.onEnterFullscreen, enterPlayerFullscreenOrientation);
    expect(video.onExitFullscreen, lockPlayerPageLandscape);
  });

  testWidgets('桌面端保持 media_kit 默认全屏回调', (tester) async {
    await pumpPlayer(tester, useTouchOptimizedControls: false);

    final video = tester.widget<Video>(find.byType(Video));
    expect(video.onEnterFullscreen, defaultEnterNativeFullscreen);
    expect(video.onExitFullscreen, defaultExitNativeFullscreen);
  });

  testWidgets('桌面端按住进度条时控件不会自动卸载', (tester) async {
    await pumpPlayer(
      tester,
      useTouchOptimizedControls: false,
      displaySeekBar: false,
      bottomControls: const <Widget>[Expanded(child: MaterialDesktopSeekBar())],
    );

    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: const Offset(1, 1));
    await mouse.moveTo(tester.getCenter(find.byType(Video)));
    await tester.pump();

    final seekBar = find.byType(MaterialDesktopSeekBar);
    expect(seekBar, findsOneWidget);

    await mouse.moveTo(tester.getCenter(seekBar));
    await mouse.down(tester.getCenter(seekBar));
    await tester.pump(const Duration(seconds: 4));

    expect(seekBar, findsOneWidget);
    expect(tester.takeException(), isNull);

    await mouse.up();
    await tester.pump(const Duration(seconds: 4));
    await tester.pump(const Duration(milliseconds: 200));

    expect(seekBar, findsNothing);
    expect(tester.takeException(), isNull);

    await mouse.removePointer();
  });

  testWidgets('桌面端控件卸载时取消自动隐藏 timer', (tester) async {
    await pumpPlayer(tester, useTouchOptimizedControls: false);

    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: const Offset(1, 1));
    await mouse.moveTo(tester.getCenter(find.byType(Video)));
    await tester.pump();
    expect(find.byType(MaterialDesktopSeekBar), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 4));

    expect(tester.takeException(), isNull);
    await mouse.removePointer();
  });
}
