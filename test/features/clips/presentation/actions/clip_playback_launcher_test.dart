import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sakuramedia/core/session/providers/session_store_provider.dart';
import 'package:sakuramedia/core/session/session_store.dart';
import 'package:sakuramedia/features/clips/presentation/actions/clip_playback_launcher.dart';
import 'package:sakuramedia/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('sakuramedia/external_player');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  tearDown(() {
    messenger.setMockMethodCallHandler(channel, null);
  });

  Future<BuildContext> pumpHarness(
    WidgetTester tester,
    _RouteLog log,
  ) async {
    final sessionStore = SessionStore.inMemory();
    await sessionStore.saveBaseUrl('https://api.example.com');
    addTearDown(sessionStore.dispose);
    late BuildContext context;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [sessionStoreProvider.overrideWithValue(sessionStore)],
        child: MaterialApp(
          locale: const Locale('zh'),
          localizationsDelegates: <LocalizationsDelegate<dynamic>>[
            AppLocalizations.delegate,
            ...GlobalMaterialLocalizations.delegates,
          ],
          supportedLocales: const <Locale>[Locale('zh'), Locale('en')],
          navigatorObservers: [log],
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

  testWidgets('移动端未配置外部播放器时推全屏切片播放页', (tester) async {
    final previousOverride = debugDefaultTargetPlatformOverride;
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    try {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final log = _RouteLog();
      final context = await pumpHarness(tester, log);
      final initialPushed = log.pushed.length;

      await tester.runAsync(() async {
        unawaited(
          launchClipPlayback(
            context,
            streamUrl: '/clips/1/play',
            title: '切片标题',
          ),
        );
        await _waitForRoute(log, initialPushed + 1);
      });

      expect(log.pushed.length, initialPushed + 1);
      expect(log.pushed.last, isA<MaterialPageRoute<void>>());
    } finally {
      debugDefaultTargetPlatformOverride = previousOverride;
    }
  });

  testWidgets('桌面未配置外部播放器时弹轻量播放弹窗', (tester) async {
    final previousOverride = debugDefaultTargetPlatformOverride;
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    try {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final log = _RouteLog();
      final context = await pumpHarness(tester, log);
      final initialPushed = log.pushed.length;

      await tester.runAsync(() async {
        unawaited(
          launchClipPlayback(
            context,
            streamUrl: '/clips/1/play',
            title: '切片标题',
          ),
        );
        await _waitForRoute(log, initialPushed + 1);
      });

      expect(log.pushed.length, initialPushed + 1);
      expect(log.pushed.last, isA<DialogRoute<void>>());
    } finally {
      debugDefaultTargetPlatformOverride = previousOverride;
    }
  });

  testWidgets('已配置外部播放器时不进入应用内播放', (tester) async {
    final previousOverride = debugDefaultTargetPlatformOverride;
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    try {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'android.external_player.package_name': 'org.videolan.vlc',
        'android.external_player.label': 'VLC',
      });
      final log = _RouteLog();
      final context = await pumpHarness(tester, log);
      final initialPushed = log.pushed.length;
      MethodCall? captured;
      messenger.setMockMethodCallHandler(channel, (call) async {
        captured = call;
        return true;
      });

      await tester.runAsync(() async {
        await launchClipPlayback(
          context,
          streamUrl: '/clips/1/play',
          title: '切片标题',
        );
      });

      expect(captured?.method, 'launch');
      expect((captured?.arguments as Map)['url'], contains('/clips/1/play'));
      expect(log.pushed.length, initialPushed);
    } finally {
      debugDefaultTargetPlatformOverride = previousOverride;
    }
  });
}

Future<void> _waitForRoute(_RouteLog log, int expected) async {
  for (var i = 0; i < 100 && log.pushed.length < expected; i++) {
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
}

class _RouteLog extends NavigatorObserver {
  final pushed = <Route<dynamic>>[];

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    pushed.add(route);
    super.didPush(route, previousRoute);
  }
}
