import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/widgets/domain/movies/player/movie_player_back_overlay.dart';

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
}
