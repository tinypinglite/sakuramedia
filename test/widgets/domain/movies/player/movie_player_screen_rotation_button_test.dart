import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:multi_split_view/multi_split_view.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/media/video/video_controls_theme.dart';
import 'package:sakuramedia/widgets/domain/media/collapsible_player_split_view.dart';
import 'package:sakuramedia/widgets/domain/movies/player/movie_player_back_overlay.dart';
import 'package:sakuramedia/widgets/domain/movies/player/movie_player_controls.dart';

import '../../../../support/pump_with_providers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late List<MethodCall> systemCalls;
  late TestDefaultBinaryMessenger messenger;

  setUp(() {
    systemCalls = <MethodCall>[];
    messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      systemCalls.add(call);
      return null;
    });
  });

  tearDown(() {
    messenger.setMockMethodCallHandler(SystemChannels.platform, null);
  });

  List<String> orientationArguments() {
    final call = systemCalls.singleWhere(
      (call) => call.method == 'SystemChrome.setPreferredOrientations',
    );
    return (call.arguments as List<Object?>).cast<String>();
  }

  testWidgets('横屏点击切到竖屏并通知宿主', (tester) async {
    var rotated = 0;
    await pumpWithProviders(
      tester,
      physicalSize: const Size(1200, 675),
      home: Scaffold(
        body: Center(
          child: MoviePlayerScreenRotationButton(onRotated: () => rotated++),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const Key('movie-player-screen-rotation-button')),
    );
    await tester.pump();

    expect(rotated, 1);
    expect(orientationArguments(), <String>['DeviceOrientation.portraitUp']);
  });

  testWidgets('竖屏点击切到横屏并通知宿主', (tester) async {
    var rotated = 0;
    await pumpWithProviders(
      tester,
      physicalSize: const Size(675, 1200),
      home: Scaffold(
        body: Center(
          child: MoviePlayerScreenRotationButton(onRotated: () => rotated++),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const Key('movie-player-screen-rotation-button')),
    );
    await tester.pump();

    expect(rotated, 1);
    expect(orientationArguments(), <String>[
      'DeviceOrientation.landscapeLeft',
      'DeviceOrientation.landscapeRight',
    ]);
  });

  testWidgets('竖屏顶栏的旋转按钮、信息按钮和面板开关不重叠', (tester) async {
    final controller = MultiSplitViewController(
      areas: <Area>[Area(flex: 1), Area(flex: 0)],
    );
    addTearDown(controller.dispose);

    await pumpWithProviders(
      tester,
      theme: buildSakuraMobileThemeData(),
      physicalSize: const Size(390, 844),
      home: Builder(
        builder: (context) {
          final trailingInset = resolveMoviePlayerTopBarTrailingInset(
            Theme.of(context),
            reserveTopRightToggle: true,
          );
          return CollapsiblePlayerSplitView(
            controller: controller,
            collapsible: true,
            panelAvailable: true,
            handleKey: const Key('panel-handle'),
            leftBuilder: (context) => Stack(
              fit: StackFit.expand,
              children: [
                const ColoredBox(color: Colors.black),
                Positioned(
                  top: context.appOverlayTokens.playerControlBarTopInset,
                  left:
                      context.appOverlayTokens.playerControlBarHorizontalInset,
                  right: trailingInset,
                  height: 56,
                  child: Row(
                    children: buildMoviePlayerTopControls(
                      movieNumber: 'ABC-123',
                      onBackPressed: () {},
                      onInfoPressed: () {},
                      onScreenRotated: () {},
                      compact: true,
                    ),
                  ),
                ),
              ],
            ),
            rightBuilder: (context) => const SizedBox.expand(),
          );
        },
      ),
    );
    await tester.pumpAndSettle();

    final rotationRect = tester.getRect(
      find.byKey(const Key('movie-player-screen-rotation-button')),
    );
    final infoRect = tester.getRect(
      find.byKey(const Key('movie-player-info-button')),
    );
    final panelRect = tester.getRect(find.byKey(const Key('panel-handle')));

    expect(rotationRect.overlaps(infoRect), isFalse);
    expect(rotationRect.overlaps(panelRect), isFalse);
    expect(infoRect.overlaps(panelRect), isFalse);
  });
}
