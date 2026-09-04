import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:media_kit/media_kit.dart';
import 'package:sakuramedia/core/network/api_client.dart';
import 'package:sakuramedia/core/network/providers/api_client_provider.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/domain/media/media_playback_info_button.dart';
import 'package:sakuramedia/widgets/domain/movies/player/movie_player_back_overlay.dart';

class _Player extends PlatformPlayer {
  _Player() : super(configuration: const PlayerConfiguration());

  String? format = 'hls';
  int propertyReads = 0;
  Future<String?> getProperty(String property) async {
    propertyReads++;
    return property == 'file-format' ? format : null;
  }

  void select(String url, {int index = 0}) {
    final playlist = Playlist([Media(url)], index: index);
    state = state.copyWith(playlist: playlist);
    playlistController.add(playlist);
  }
}

class _Api extends Fake implements ApiClient {
  final responses = <String, Future<Map<String, dynamic>>>{};
  final requests = <String>[];

  @override
  Future<Map<String, dynamic>> get(
    String path, {
    Map<String, dynamic>? queryParameters,
    bool requiresAuth = true,
    Duration? connectTimeout,
    Duration? receiveTimeout,
  }) {
    requests.add(path);
    return responses[path] ?? Future.value({'mode': null});
  }
}

void main() {
  testWidgets(
    'single and playlist playback share a live panel and discard stale modes',
    (tester) async {
      final native = _Player();
      final player = Player(platformPlayer: native);
      final api = _Api();
      final oldMode = Completer<Map<String, dynamic>>();
      api.responses['/media/playback-attempts/first'] = oldMode.future;
      native.select('https://backend/media/1/play/?playback_attempt_id=first');
      await tester.pumpWidget(
        ProviderScope(
          overrides: [apiClientProvider.overrideWithValue(api)],
          child: MaterialApp(
            theme: sakuraThemeData,
            home: Scaffold(body: MediaPlaybackInfoButton(player: player)),
          ),
        ),
      );
      await tester.tap(find.byKey(const Key('movie-player-info-button')));
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('播放信息'), findsOneWidget);
      expect(find.text('HLS'), findsOneWidget);
      expect(find.text('/media/1/play/'), findsOneWidget);

      native.format = 'mov,mp4';
      native.select('https://backend/media-clips/2/stream?signature=secret');
      await tester.pump();
      oldMode.complete({'mode': 'direct'});
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('HTTP 文件流'), findsOneWidget);
      expect(find.text('后端代理'), findsOneWidget);
      expect(find.text('直连'), findsNothing);
      expect(find.text('/media-clips/2/stream'), findsOneWidget);
      expect(find.textContaining('signature=secret'), findsNothing);
      expect(api.requests, ['/media/playback-attempts/first']);

      await tester.tapAt(const Offset(10, 300));
      await tester.pumpAndSettle();
      expect(find.text('播放信息'), findsNothing);
      await tester.pumpWidget(const SizedBox());
      await player.dispose();
    },
  );

  testWidgets(
    'info button on a fullscreen route opens above that route and closes normally',
    (tester) async {
      final native = _Player()..format = 'mp4';
      final player = Player(platformPlayer: native);
      native.select('https://backend/media-clips/3/stream');
      final navigator = GlobalKey<NavigatorState>();
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            navigatorKey: navigator,
            theme: sakuraThemeData,
            home: const Scaffold(body: Text('window')),
          ),
        ),
      );
      unawaited(
        navigator.currentState!.push(
          MaterialPageRoute<void>(
            builder: (_) =>
                Scaffold(body: MediaPlaybackInfoButton(player: player)),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('movie-player-info-button')));
      await tester.pumpAndSettle();
      expect(find.text('HTTP 文件流'), findsOneWidget);
      navigator.currentState!.pop();
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('movie-player-info-button')), findsOneWidget);
      navigator.currentState!.pop();
      await tester.pumpAndSettle();
      expect(find.text('window'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      await player.dispose();
    },
  );

  testWidgets(
    'root info stays live after controls hide and stops when closed',
    (tester) async {
      final native = _Player();
      final player = Player(platformPlayer: native);
      final api = _Api();
      api.responses['/media/playback-attempts/second'] = Future.value({
        'mode': 'direct',
      });
      native.select('https://backend/media-clips/1/stream');
      late StateSetter updateControls;
      var showControls = true;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [apiClientProvider.overrideWithValue(api)],
          child: MaterialApp(
            theme: sakuraThemeData,
            home: Scaffold(
              body: StatefulBuilder(
                builder: (context, setState) {
                  updateControls = setState;
                  return showControls
                      ? MediaPlaybackInfoButton(player: player)
                      : const SizedBox();
                },
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.byKey(const Key('movie-player-info-button')));
      await tester.pumpAndSettle();
      expect(find.text('HLS'), findsOneWidget);

      updateControls(() => showControls = false);
      await tester.pump();
      expect(find.byKey(const Key('movie-player-info-button')), findsNothing);
      native.format = 'mp4';
      native.select('https://backend/media/2/play/?playback_attempt_id=second');
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('播放信息'), findsOneWidget);
      expect(find.text('HTTP 文件流'), findsOneWidget);
      expect(find.text('/media/2/play/'), findsOneWidget);
      expect(find.text('直连'), findsOneWidget);

      await tester.tapAt(const Offset(10, 300));
      await tester.pumpAndSettle();
      expect(find.text('播放信息'), findsNothing);
      final readsAfterClose = native.propertyReads;
      await tester.pump(const Duration(seconds: 2));
      expect(native.propertyReads, readsAfterClose);
      await tester.pumpWidget(const SizedBox());
      await player.dispose();
    },
  );

  testWidgets('local overlay keeps the info drawer inside its player pane', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(800, 600));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final native = _Player();
    final player = Player(platformPlayer: native);
    final infoController = MediaPlaybackInfoController(
      player: player,
      readApiClient: _Api.new,
    );
    addTearDown(infoController.dispose);
    native.select('https://backend/media-clips/4/stream');
    const paneKey = Key('player-pane');
    var showTrigger = true;

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: sakuraThemeData,
          home: Scaffold(
            body: Row(
              children: [
                SizedBox(
                  key: paneKey,
                  width: 480,
                  child: Overlay(
                    initialEntries: [
                      OverlayEntry(
                        builder: (_) => Positioned.fill(
                          child: StatefulBuilder(
                            builder: (context, setState) => showTrigger
                                ? MoviePlayerInfoButton(
                                    onPressed: () {
                                      infoController.showLocal(context);
                                      setState(() => showTrigger = false);
                                    },
                                  )
                                : const SizedBox.shrink(),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const Expanded(child: ColoredBox(color: Colors.black)),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.byKey(const Key('movie-player-info-button')));
    await tester.pumpAndSettle();

    final paneRect = tester.getRect(find.byKey(paneKey));
    final drawerRect = tester.getRect(
      find.byKey(const Key('movie-player-info-side-drawer')),
    );
    expect(drawerRect.right, closeTo(paneRect.right - 10, 0.01));
    expect(
      drawerRect.right,
      isNot(tester.getRect(find.byType(Scaffold)).right),
    );

    infoController.dispose();
    await tester.pumpWidget(const SizedBox());
    await player.dispose();
  });
}
