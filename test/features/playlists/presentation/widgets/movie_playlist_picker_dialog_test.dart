import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/app/app_platform.dart';
import 'package:sakuramedia/core/session/session_store.dart';
import 'package:sakuramedia/features/movies/data/dto/detail/movie_detail_dto.dart';
import 'package:sakuramedia/features/playlists/data/dto/playlist_dto.dart';
import 'package:sakuramedia/features/playlists/presentation/widgets/movie_playlist_picker_dialog.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/overlays/app_adaptive_modal.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../support/logged_in_session_store.dart';
import '../../../../support/preview_helpers.dart';
import '../../../../support/test_api_bundle.dart';

const _initialPlaylists = <MoviePlaylistSummaryDto>[
  MoviePlaylistSummaryDto(
    id: 1,
    name: '稍后再看',
    kind: PlaylistKind.custom,
    isSystem: false,
  ),
];

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
        _playlistJson(
          id: 1,
          name: '稍后再看',
          kind: PlaylistKind.custom,
          isSystem: false,
          movieCount: 3,
        ),
        _playlistJson(
          id: 2,
          name: '最近播放',
          kind: PlaylistKind.recentlyPlayed,
          isSystem: true,
          movieCount: 9,
        ),
        _playlistJson(
          id: 3,
          name: '收藏夹',
          kind: PlaylistKind.favorites,
          isSystem: true,
          movieCount: 5,
        ),
      ],
    );
  });

  tearDown(() {
    bundle.dispose();
    sessionStore.dispose();
  });

  testWidgets('filters system playlists, searches and toggles membership', (
    tester,
  ) async {
    bundle.adapter.setFallbackJson(
      method: 'DELETE',
      path: '/playlists/1/movies/ABC-001',
      statusCode: 204,
    );
    bundle.adapter.setFallbackJson(
      method: 'PUT',
      path: '/playlists/3/movies/ABC-001',
      statusCode: 204,
    );

    await _openPicker(
      tester,
      bundle: bundle,
      presentation: AppAdaptiveModalVariant.dialog,
    );

    expect(
      find.byKey(const Key('movie-playlist-picker-dialog')),
      findsOneWidget,
    );
    expect(find.text('稍后再看'), findsOneWidget);
    expect(find.text('收藏夹'), findsOneWidget);
    expect(find.text('最近播放'), findsNothing);
    expect(find.text('3 部'), findsOneWidget);
    expect(find.text('已选 1'), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('movie-playlist-search-field')),
      '收藏',
    );
    await _pumpFrames(tester);
    expect(find.text('稍后再看'), findsNothing);
    expect(find.text('收藏夹'), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('movie-playlist-search-field')),
      '',
    );
    await _pumpFrames(tester);
    await tester.tap(find.byKey(const Key('movie-playlist-option-1')));
    await _pumpFrames(tester);
    expect(bundle.adapter.hitCount('DELETE', '/playlists/1/movies/ABC-001'), 1);
    expect(find.text('已选 0'), findsOneWidget);

    await tester.tap(find.byKey(const Key('movie-playlist-option-3')));
    await _pumpFrames(tester);
    expect(bundle.adapter.hitCount('PUT', '/playlists/3/movies/ABC-001'), 1);
    expect(find.text('已选 1'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'bottom drawer keeps its legacy key and rolls back failed remove',
    (tester) async {
      bundle.adapter.setFallbackJson(
        method: 'DELETE',
        path: '/playlists/1/movies/ABC-001',
        statusCode: 500,
        body: <String, dynamic>{
          'error': <String, dynamic>{
            'code': 'playlist_unavailable',
            'message': '播放列表服务不可用',
          },
        },
      );

      await _openPicker(
        tester,
        bundle: bundle,
        presentation: AppAdaptiveModalVariant.drawer,
      );

      expect(
        find.byKey(const Key('movie-playlist-picker-bottom-sheet')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('movie-playlist-picker-dialog')),
        findsNothing,
      );

      await tester.tap(find.byKey(const Key('movie-playlist-option-1')));
      await _pumpFrames(tester);
      expect(
        bundle.adapter.hitCount('DELETE', '/playlists/1/movies/ABC-001'),
        1,
      );
      expect(find.text('已选 1'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pump(const Duration(seconds: 4));
      await tester.pumpAndSettle();
    },
  );
}

Future<void> _openPicker(
  WidgetTester tester, {
  required TestApiBundle bundle,
  required AppAdaptiveModalVariant presentation,
}) async {
  await pumpPreviewApp(
    tester,
    home: _PickerLauncher(presentation: presentation),
    size: presentation == AppAdaptiveModalVariant.drawer
        ? const Size(390, 844)
        : const Size(1100, 760),
    theme: presentation == AppAdaptiveModalVariant.drawer
        ? buildSakuraMobileThemeData()
        : buildSakuraDesktopThemeData(),
    platform: presentation == AppAdaptiveModalVariant.drawer
        ? TargetPlatform.android
        : TargetPlatform.macOS,
    appPlatform: presentation == AppAdaptiveModalVariant.drawer
        ? AppPlatform.mobile
        : AppPlatform.desktop,
    bundle: bundle,
    settle: false,
  );
  await tester.tap(find.byKey(const Key('open-movie-playlist-picker')));
  await _pumpFrames(tester);
}

class _PickerLauncher extends StatelessWidget {
  const _PickerLauncher({required this.presentation});

  final AppAdaptiveModalVariant presentation;

  @override
  Widget build(BuildContext context) {
    return Builder(
      builder: (context) => Center(
        child: TextButton(
          key: const Key('open-movie-playlist-picker'),
          onPressed: () => showMoviePlaylistPickerDialog(
            context,
            movieNumber: 'ABC-001',
            initialPlaylists: _initialPlaylists,
            presentation: presentation,
          ),
          child: const Text('open'),
        ),
      ),
    );
  }
}

Map<String, dynamic> _playlistJson({
  required int id,
  required String name,
  required String kind,
  required bool isSystem,
  required int movieCount,
}) {
  return <String, dynamic>{
    'id': id,
    'name': name,
    'kind': kind,
    'description': '',
    'is_system': isSystem,
    'is_mutable': !isSystem,
    'is_deletable': !isSystem,
    'movie_count': movieCount,
  };
}

Future<void> _pumpFrames(WidgetTester tester) async {
  for (var index = 0; index < 10; index++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}
