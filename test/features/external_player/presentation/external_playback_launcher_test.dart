import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sakuramedia/features/external_player/presentation/external_playback_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('sakuramedia/external_player');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  tearDown(() {
    messenger.setMockMethodCallHandler(channel, null);
  });

  Future<BuildContext> pumpContext(WidgetTester tester) async {
    late BuildContext context;
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Builder(
            builder: (innerContext) {
              context = innerContext;
              return const SizedBox();
            },
          ),
        ),
      ),
    );
    return context;
  }

  testWidgets('已配置时用解析后的地址拉起外部播放器', (tester) async {
    final previousOverride = debugDefaultTargetPlatformOverride;
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    try {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'android.external_player.package_name': 'org.videolan.vlc',
        'android.external_player.label': 'VLC',
      });
      final context = await pumpContext(tester);
      MethodCall? captured;
      messenger.setMockMethodCallHandler(channel, (call) async {
        captured = call;
        return true;
      });

      final launched = await tryLaunchConfiguredExternalPlayer(
        context,
        title: '视频标题',
        resolveUrl: () async => 'https://media.example.com/video.mp4',
      );

      expect(launched, isTrue);
      expect(captured?.method, 'launch');
      expect((captured?.arguments as Map)['playerId'], 'org.videolan.vlc');
      expect(
        (captured?.arguments as Map)['url'],
        'https://media.example.com/video.mp4',
      );
    } finally {
      debugDefaultTargetPlatformOverride = previousOverride;
    }
  });

  testWidgets('未配置时保留应用内播放且不解析播放地址', (tester) async {
    final previousOverride = debugDefaultTargetPlatformOverride;
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    try {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final context = await pumpContext(tester);
      var resolved = false;

      final launched = await tryLaunchConfiguredExternalPlayer(
        context,
        title: '视频标题',
        resolveUrl: () async {
          resolved = true;
          return 'https://media.example.com/video.mp4';
        },
      );

      expect(launched, isFalse);
      expect(resolved, isFalse);
    } finally {
      debugDefaultTargetPlatformOverride = previousOverride;
    }
  });
}
