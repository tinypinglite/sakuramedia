import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/core/session/session_store.dart';
import 'package:sakuramedia/features/movies/presentation/controllers/listing/movie_filter_state.dart';
import 'package:sakuramedia/features/playlists/data/dto/playlist_dto.dart';
import 'package:sakuramedia/features/playlists/presentation/controllers/smart_playlist_draft.dart';
import 'package:sakuramedia/features/playlists/presentation/widgets/playlist_type_chooser.dart';
import 'package:sakuramedia/features/playlists/presentation/widgets/smart_playlist_editor.dart';
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
      path: '/tags',
      body: <dynamic>[],
    );
  });

  tearDown(() {
    bundle.dispose();
    sessionStore.dispose();
  });

  test('SmartPlaylistDraft serializes every multi-select filter dimension', () {
    final draft = SmartPlaylistDraft.fromFilter(
      const SmartPlaylistFilterDto(
        statuses: <String>['subscribed', 'playable'],
        statusMatch: 'and',
        watchStatuses: <String>['unwatched', 'watching'],
        watchMatch: 'or',
        collectionType: 'all',
        numberSource: 'fc2',
        sort: 'heat:asc',
        years: <int>[2024, 2023],
        resolutions: <String>['1080P', '4K'],
        tagIds: <int>[1, 2],
        tagMatch: 'and',
        mediaTagIds: <int>[3, 5],
        mediaTagMatch: 'and',
        actorIds: <int>[7, 8],
        actorMatch: 'and',
        actorAgeMin: 20,
        actorAgeMax: 30,
        heatMin: 100,
        heatMax: 900,
      ),
    );

    final json = draft.toFilterJson(
      tagIds: const <int>[1, 2],
      tagMatch: TagMatchMode.and,
    );

    expect(json, <String, dynamic>{
      'statuses': <String>['subscribed', 'playable'],
      'status_match': 'and',
      'watch_statuses': <String>['unwatched', 'watching'],
      'watch_match': 'or',
      'collection_type': 'all',
      'number_source': 'fc2',
      'sort': 'heat:asc',
      'years': <int>[2023, 2024],
      'resolutions': <String>['4K', '1080P'],
      'tag_ids': <int>[1, 2],
      'tag_match': 'and',
      'media_tag_ids': <int>[3, 5],
      'media_tag_match': 'and',
      'actor_ids': <int>[7, 8],
      'actor_match': 'and',
      'actor_age_min': 20,
      'actor_age_max': 30,
      'heat_min': 100,
      'heat_max': 900,
    });
  });

  test('resolutions are dropped when playable status is not selected', () {
    const draft = SmartPlaylistDraft(
      statuses: <MovieStatusFilter>{MovieStatusFilter.subscribed},
      resolutions: <PlaylistResolutionFilter>{PlaylistResolutionFilter.k4k},
    );

    final json = draft.toFilterJson(
      tagIds: const <int>[],
      tagMatch: TagMatchMode.or,
    );

    expect(json['resolutions'], isEmpty);
  });

  testWidgets('creates a smart playlist with multi-select filters', (
    tester,
  ) async {
    bundle.adapter.setFallbackJson(
      method: 'POST',
      path: '/playlists',
      statusCode: 201,
      body: _playlistJson(),
    );

    await pumpPreviewApp(
      tester,
      home: const _EditorLauncher(),
      size: const Size(1100, 900),
      theme: buildSakuraDesktopThemeData(),
      platform: TargetPlatform.macOS,
      bundle: bundle,
    );

    await tester.tap(find.byKey(const Key('open-smart-playlist-editor')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('smart-playlist-editor-form')), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('smart-playlist-name-field')),
      '高分未看',
    );
    const playableKey = Key('smart-playlist-status-playable');
    await tester.ensureVisible(find.byKey(playableKey));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(playableKey));
    await tester.pumpAndSettle();
    const k4kKey = Key('smart-playlist-resolution-k4k');
    await tester.ensureVisible(find.byKey(k4kKey));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(k4kKey));
    await tester.pumpAndSettle();
    const unwatchedKey = Key('smart-playlist-watch-status-unwatched');
    await tester.ensureVisible(find.byKey(unwatchedKey));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(unwatchedKey));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('smart-playlist-editor-submit')));
    await tester.pumpAndSettle();

    final request = bundle.adapter.requests.lastWhere(
      (item) => item.method == 'POST' && item.path == '/playlists',
    );
    expect(request.body['name'], '高分未看');
    expect(request.body['kind'], 'smart');
    final filter = request.body['filter'] as Map<String, dynamic>;
    expect(filter['statuses'], <String>['playable']);
    expect(filter['watch_statuses'], <String>['unwatched']);
    expect(filter['resolutions'], <String>['4K']);
    expect(filter['collection_type'], 'single');
    expect(filter['actor_ids'], isEmpty);
    expect(filter['tag_ids'], isEmpty);
    expect(filter['sort'], 'release_date:desc');
  });

  testWidgets('playlist type chooser offers smart creation', (tester) async {
    await pumpPreviewApp(
      tester,
      home: const _ChooserLauncher(),
      size: const Size(1100, 760),
      theme: buildSakuraDesktopThemeData(),
      platform: TargetPlatform.macOS,
      bundle: bundle,
    );

    await tester.tap(find.byKey(const Key('open-playlist-type-chooser')));
    await tester.pumpAndSettle();
    expect(find.text('普通列表'), findsOneWidget);
    expect(find.text('智能列表'), findsOneWidget);

    await tester.tap(find.byKey(const Key('playlist-type-smart')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('chooser-result-smart')), findsOneWidget);
  });
}

class _EditorLauncher extends StatelessWidget {
  const _EditorLauncher();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: TextButton(
        key: const Key('open-smart-playlist-editor'),
        onPressed: () => showSmartPlaylistEditor(context),
        child: const Text('open'),
      ),
    );
  }
}

class _ChooserLauncher extends StatefulWidget {
  const _ChooserLauncher();

  @override
  State<_ChooserLauncher> createState() => _ChooserLauncherState();
}

class _ChooserLauncherState extends State<_ChooserLauncher> {
  String? _result;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextButton(
            key: const Key('open-playlist-type-chooser'),
            onPressed: () async {
              final kind = await showPlaylistTypeChooser(context);
              if (!mounted) return;
              setState(() => _result = kind);
            },
            child: const Text('open'),
          ),
          if (_result != null)
            Text(
              _result == PlaylistKind.smart ? 'smart' : 'custom',
              key: Key('chooser-result-$_result'),
            ),
        ],
      ),
    );
  }
}

Map<String, dynamic> _playlistJson() {
  return <String, dynamic>{
    'id': 21,
    'name': '高分未看',
    'kind': 'smart',
    'description': '',
    'is_system': false,
    'is_mutable': true,
    'is_deletable': true,
    'is_smart': true,
    'smart_filter': <String, dynamic>{
      'statuses': <String>['playable'],
      'watch_statuses': <String>['unwatched'],
      'resolutions': <String>['4K'],
      'actor_ids': <int>[],
      'actor_match': 'or',
    },
    'movie_count': 3,
    'created_at': '2026-03-12T10:10:00Z',
    'updated_at': '2026-03-12T10:10:00Z',
  };
}
