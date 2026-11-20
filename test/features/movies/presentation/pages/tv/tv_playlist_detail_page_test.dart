import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/app/app_platform.dart';
import 'package:sakuramedia/core/session/session_store.dart';
import 'package:sakuramedia/features/movies/presentation/pages/tv/tv_playlist_detail_page.dart';
import 'package:sakuramedia/features/playlists/presentation/controllers/playlist_filter_state.dart';
import 'package:sakuramedia/features/plugins/presentation/providers/plugin_capabilities_provider.dart';
import 'package:sakuramedia/l10n/app_localizations_zh.dart';
import 'package:sakuramedia/theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../../support/fake_http_client_adapter.dart';
import '../../../../../support/logged_in_session_store.dart';
import '../../../../../support/preview_helpers.dart';
import '../../../../../support/test_api_bundle.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final l10n = AppLocalizationsZh();
  late SessionStore sessionStore;
  late TestApiBundle bundle;

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    sessionStore = await buildLoggedInSessionStore();
    bundle = await createTestApiBundle(sessionStore);
    bundle.adapter.setFallbackJson(
      method: 'GET',
      path: '/playlists/7/movies',
      body: _moviesPage(),
    );
    bundle.adapter.setFallbackJson(
      method: 'GET',
      path: '/playlists/8/movies',
      body: _moviesPage(),
    );
  });

  tearDown(() {
    bundle.dispose();
    sessionStore.dispose();
  });

  testWidgets('智能列表首拉带保存筛选和标签，排序不会丢掉它们', (tester) async {
    bundle.adapter.setFallbackJson(
      method: 'GET',
      path: '/playlists/7',
      body: _smartPlaylistJson(),
    );

    await _pumpPage(tester, bundle, playlistId: 7);

    final first = _lastMoviesRequest(bundle, 7).uri.queryParameters;
    expect(first['statuses'], 'playable');
    expect(first['status_match'], 'and');
    expect(first['watch_statuses'], 'unwatched');
    expect(first['watch_match'], 'or');
    expect(first['year'], '2024');
    expect(first['resolutions'], '4K');
    expect(first['tag_ids'], '1,2');
    expect(first['tag_match'], 'and');
    expect(first['media_tag_ids'], '3');
    expect(first['media_tag_match'], 'and');
    expect(first.containsKey('sort'), isFalse);
    expect(
      find.text(
        l10n.tvSortEntryLabel(playlistSortLabel('release_date:asc', l10n)!),
      ),
      findsOneWidget,
    );

    await _openSortDialog(tester);
    await tester.tap(find.byKey(const Key('tv-sort-field-addedAt')));
    await _applySort(tester);

    final sorted = _lastMoviesRequest(bundle, 7).uri.queryParameters;
    expect(sorted['sort'], 'added_at:desc');
    expect(sorted['statuses'], 'playable');
    expect(sorted['watch_statuses'], 'unwatched');
    expect(sorted['tag_ids'], '1,2');
    expect(sorted['media_tag_ids'], '3');

    await _openSortDialog(tester);
    await tester.tap(find.byKey(const Key('tv-sort-default')));
    await _applySort(tester);

    final restored = _lastMoviesRequest(bundle, 7).uri.queryParameters;
    expect(restored.containsKey('sort'), isFalse);
    expect(restored['statuses'], 'playable');
    expect(restored['tag_ids'], '1,2');
    expect(tester.takeException(), isNull);
  });

  testWidgets('普通列表仍发送空覆盖参数并使用最近触达作为默认排序', (tester) async {
    bundle.adapter.setFallbackJson(
      method: 'GET',
      path: '/playlists/8',
      body: _customPlaylistJson(),
    );

    await _pumpPage(tester, bundle, playlistId: 8);

    final query = _lastMoviesRequest(bundle, 8).uri.queryParameters;
    expect(query['statuses'], '');
    expect(query['watch_statuses'], '');
    expect(query['tag_ids'], '');
    expect(query.containsKey('sort'), isFalse);
    expect(
      find.text(l10n.tvSortEntryLabel(l10n.playlistSortDefault)),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
}

Future<void> _openSortDialog(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('tv-sort-trigger')));
  await tester.pumpAndSettle();
  expect(find.byKey(const Key('tv-sort-dialog')), findsOneWidget);
}

Future<void> _applySort(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('tv-sort-apply')));
  await _pumpFrames(tester);
}

final _overrides = <Override>[
  statsFeaturesEnabledProvider.overrideWithValue(true),
];

Future<void> _pumpPage(
  WidgetTester tester,
  TestApiBundle bundle, {
  required int playlistId,
}) async {
  await pumpPreviewApp(
    tester,
    home: TvPlaylistDetailPage(
      playlistId: playlistId,
      playlistName: '播放列表 $playlistId',
    ),
    size: const Size(1920, 1080),
    theme: buildSakuraTvThemeData(),
    platform: TargetPlatform.android,
    appPlatform: AppPlatform.tv,
    bundle: bundle,
    extraOverrides: _overrides,
    settle: false,
  );
  await _pumpFrames(tester);
}

Future<void> _pumpFrames(WidgetTester tester) async {
  for (var index = 0; index < 15; index++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

RecordedRequest _lastMoviesRequest(TestApiBundle bundle, int playlistId) {
  return bundle.adapter.requests.lastWhere(
    (request) => request.uri.path == '/playlists/$playlistId/movies',
  );
}

Map<String, dynamic> _smartPlaylistJson() {
  return <String, dynamic>{
    'id': 7,
    'name': '高分未看',
    'kind': 'smart',
    'description': '',
    'is_system': false,
    'is_mutable': true,
    'is_deletable': true,
    'is_smart': true,
    'smart_filter': <String, dynamic>{
      'statuses': <String>['playable'],
      'status_match': 'and',
      'watch_statuses': <String>['unwatched'],
      'watch_match': 'or',
      'years': <int>[2024],
      'resolutions': <String>['4K'],
      'tag_ids': <int>[1, 2],
      'tag_match': 'and',
      'media_tag_ids': <int>[3],
      'media_tag_match': 'and',
      'sort': 'release_date:asc',
    },
    'movie_count': 12,
    'created_at': '2026-03-12T10:10:00Z',
    'updated_at': '2026-03-12T10:10:00Z',
  };
}

Map<String, dynamic> _customPlaylistJson() {
  return <String, dynamic>{
    'id': 8,
    'name': '普通列表',
    'kind': 'custom',
    'description': '',
    'is_system': false,
    'is_mutable': true,
    'is_deletable': true,
    'is_smart': false,
    'smart_filter': null,
    'movie_count': 3,
    'created_at': '2026-03-12T10:10:00Z',
    'updated_at': '2026-03-12T10:10:00Z',
  };
}

Map<String, dynamic> _moviesPage() {
  return <String, dynamic>{
    'items': <Map<String, dynamic>>[
      <String, dynamic>{
        'movie_number': 'ABC-001',
        'title': 'Movie ABC-001',
        'cover_image': null,
        'release_date': '2024-01-02',
        'duration_minutes': 120,
        'heat': 1,
        'is_subscribed': false,
        'can_play': true,
      },
    ],
    'page': 1,
    'page_size': 36,
    'total': 1,
  };
}
