import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/app/app_platform.dart';
import 'package:sakuramedia/core/session/session_store.dart';
import 'package:sakuramedia/features/playlists/data/dto/playlist_dto.dart';
import 'package:sakuramedia/features/playlists/presentation/widgets/movie_playlist_target_picker.dart';
import 'package:sakuramedia/theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../support/logged_in_session_store.dart';
import '../../../../support/preview_helpers.dart';
import '../../../../support/test_api_bundle.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SessionStore sessionStore;
  late TestApiBundle bundle;

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    sessionStore = await buildLoggedInSessionStore();
    bundle = await createTestApiBundle(sessionStore);
    bundle.adapter.setFallbackJson(
      method: 'GET',
      path: '/playlists',
      body: <Map<String, dynamic>>[
        _playlistJson(id: 1, name: 'Current', kind: PlaylistKind.custom),
        _playlistJson(id: 2, name: 'Favorites', kind: PlaylistKind.favorites),
        _playlistJson(
          id: 3,
          name: 'Recently played',
          kind: PlaylistKind.recentlyPlayed,
        ),
        _playlistJson(id: 4, name: 'My list', kind: PlaylistKind.custom),
      ],
    );
  });

  tearDown(() {
    bundle.dispose();
    sessionStore.dispose();
  });

  testWidgets('filters targets, searches, and excludes current playlist', (
    tester,
  ) async {
    PlaylistDto? picked;
    await pumpPreviewApp(
      tester,
      home: _PickerLauncher(
        excludedPlaylistId: 1,
        onResult: (result) => picked = result,
      ),
      size: const Size(1100, 760),
      theme: buildSakuraDesktopThemeData(),
      platform: TargetPlatform.macOS,
      appPlatform: AppPlatform.desktop,
      bundle: bundle,
      settle: false,
    );

    await tester.tap(
      find.byKey(const Key('open-movie-playlist-target-picker')),
    );
    await _pumpFrames(tester);

    expect(
      find.byKey(const Key('movie-playlist-target-picker-option-1')),
      findsNothing,
    );
    expect(
      find.byKey(const Key('movie-playlist-target-picker-option-3')),
      findsNothing,
    );
    expect(
      find.byKey(const Key('movie-playlist-target-picker-option-2')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('movie-playlist-target-picker-option-4')),
      findsOneWidget,
    );

    await tester.enterText(
      find.byKey(const Key('collection-target-picker-search-field')),
      'My',
    );
    await _pumpFrames(tester);

    expect(
      find.byKey(const Key('movie-playlist-target-picker-option-2')),
      findsNothing,
    );
    expect(
      find.byKey(const Key('movie-playlist-target-picker-option-4')),
      findsOneWidget,
    );

    await tester.tap(
      find.byKey(const Key('movie-playlist-target-picker-option-4')),
    );
    await _pumpFrames(tester);

    expect(picked?.id, 4);
    expect(tester.takeException(), isNull);
  });

  testWidgets('creates a playlist and returns it as the selected target', (
    tester,
  ) async {
    bundle.adapter.enqueueJson(
      method: 'POST',
      path: '/playlists',
      statusCode: 201,
      body: _playlistJson(id: 9, name: 'New list', kind: PlaylistKind.custom),
    );
    PlaylistDto? picked;

    await pumpPreviewApp(
      tester,
      home: _PickerLauncher(onResult: (result) => picked = result),
      size: const Size(1100, 760),
      theme: buildSakuraDesktopThemeData(),
      platform: TargetPlatform.macOS,
      appPlatform: AppPlatform.desktop,
      bundle: bundle,
      settle: false,
    );

    await tester.tap(
      find.byKey(const Key('open-movie-playlist-target-picker')),
    );
    await _pumpFrames(tester);
    await tester.tap(
      find.byKey(const Key('collection-target-picker-create-button')),
    );
    await _pumpFrames(tester);
    await tester.enterText(
      find.byKey(const Key('create-playlist-name-field')),
      'New list',
    );
    await tester.tap(find.byKey(const Key('create-playlist-submit-button')));
    await _pumpFrames(tester);

    expect(picked?.id, 9);
    expect(bundle.adapter.hitCount('POST', '/playlists'), 1);
    expect(tester.takeException(), isNull);
  });
}

class _PickerLauncher extends StatelessWidget {
  const _PickerLauncher({this.excludedPlaylistId, required this.onResult});

  final int? excludedPlaylistId;
  final ValueChanged<PlaylistDto?> onResult;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: TextButton(
        key: const Key('open-movie-playlist-target-picker'),
        onPressed: () async {
          final result = await showMoviePlaylistTargetPicker(
            context,
            excludedPlaylistId: excludedPlaylistId,
          );
          onResult(result);
        },
        child: const Text('open'),
      ),
    );
  }
}

Map<String, dynamic> _playlistJson({
  required int id,
  required String name,
  required String kind,
}) {
  return <String, dynamic>{
    'id': id,
    'name': name,
    'kind': kind,
    'description': '',
    'is_system': kind != PlaylistKind.custom,
    'is_mutable': kind == PlaylistKind.custom,
    'is_deletable': kind == PlaylistKind.custom,
    'movie_count': 2,
  };
}

Future<void> _pumpFrames(WidgetTester tester) async {
  for (var index = 0; index < 10; index++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}
