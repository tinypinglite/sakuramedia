import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:material_ui/material_ui.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sakuramedia/core/session/session_store.dart';
import 'package:sakuramedia/features/movies/presentation/pages/shared/movie_merged_play_content.dart';
import 'package:sakuramedia/features/shared/presentation/providers/merged_playback_factory_provider.dart';
import 'package:sakuramedia/l10n/app_localizations.dart';
import 'package:sakuramedia/theme.dart';

import '../../../../support/test_api_bundle.dart';
import '../../../../support/test_playlist_player.dart';

class _VideoController extends Fake implements VideoController {
  _VideoController(this.player);

  @override
  final Player player;

  @override
  final notifier = ValueNotifier<PlatformVideoController?>(null);

  @override
  Future<void> get waitUntilFirstFrameRendered => Future<void>.value();
}

Map<String, dynamic> _media(int id, int libraryId, {bool valid = true}) =>
    <String, dynamic>{
      'media_id': id,
      'library_id': libraryId,
      'library_name': '主媒体库',
      'provider_key': 'local',
      'file_name': 'TEST-001-CD$id.mp4',
      'duration_seconds': 600,
      'valid': valid,
      'play_url': '/media/$id/play/file.mp4',
    };

Map<String, dynamic> _movie() => <String, dynamic>{
  'movie_number': 'TEST-001',
  'title': '多段影片',
  'can_play': true,
  'media_items': <Map<String, dynamic>>[
    _media(1, 1),
    _media(2, 1),
    _media(3, 1, valid: false),
    _media(4, 2),
  ],
};

void main() {
  testWidgets('旧深链缺少 mediaIds 时不再回退整库合并', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1100, 760);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    final session = SessionStore.inMemory();
    await session.saveBaseUrl('https://api.example.com');
    final bundle = await createTestApiBundle(session);
    addTearDown(bundle.dispose);
    addTearDown(session.dispose);
    bundle.adapter.enqueueJson(
      method: 'GET',
      path: '/movies/TEST-001',
      body: _movie(),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: bundle.riverpodOverrides(),
        child: MaterialApp(
          theme: buildSakuraDesktopThemeData(),
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const MovieMergedPlayContent(
            movieNumber: 'TEST-001',
            libraryId: 1,
            fallbackPath: '/desktop/library/movies/TEST-001',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.text(
        'The selected media segments are unavailable. Please choose again.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('应用内播放器严格按用户选择的媒体顺序建立 Playlist', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1100, 760);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    final messenger = tester.binding.defaultBinaryMessenger;
    const videoChannel = MethodChannel('com.alexmercerind/media_kit_video');
    messenger.setMockMethodCallHandler(videoChannel, (_) async => null);
    addTearDown(() => messenger.setMockMethodCallHandler(videoChannel, null));

    final session = SessionStore.inMemory();
    await session.saveBaseUrl('https://api.example.com');
    final bundle = await createTestApiBundle(session);
    addTearDown(bundle.dispose);
    addTearDown(session.dispose);
    bundle.adapter.enqueueJson(
      method: 'GET',
      path: '/movies/TEST-001',
      body: _movie(),
    );
    for (final id in <int>[2, 1]) {
      bundle.adapter.enqueueJson(
        method: 'GET',
        path: '/media/$id/thumbnails',
        body: const <Map<String, dynamic>>[],
      );
    }

    final native = TestPlaylistPlayer();
    final player = Player(platformPlayer: native);
    final controller = _VideoController(player);
    addTearDown(controller.notifier.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          ...bundle.riverpodOverrides(),
          mergedPlaybackFactoryProvider.overrideWithValue(
            () => (player: player, videoController: controller),
          ),
        ],
        child: MaterialApp(
          theme: buildSakuraDesktopThemeData(),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const MovieMergedPlayContent(
            movieNumber: 'TEST-001',
            libraryId: 1,
            mediaIds: <int>[2, 1],
            fallbackPath: '/desktop/library/movies/TEST-001',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(native.state.playlist.medias, hasLength(2));
    expect(
      native.state.playlist.medias.map((media) => media.uri).toList(),
      <String>[
        'https://api.example.com/media/2/play/file.mp4',
        'https://api.example.com/media/1/play/file.mp4',
      ],
    );
  });
}
