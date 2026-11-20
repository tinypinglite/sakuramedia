import 'package:flutter_test/flutter_test.dart';
import 'package:sakuramedia/core/network/api_client.dart';
import 'package:sakuramedia/core/network/api_exception.dart';
import 'package:sakuramedia/core/session/session_store.dart';
import 'package:sakuramedia/features/playlists/data/dto/playlist_dto.dart';
import 'package:sakuramedia/features/playlists/data/api/playlists_api.dart';

import '../../../../support/fake_http_client_adapter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SessionStore sessionStore;
  late ApiClient apiClient;
  late PlaylistsApi playlistsApi;
  late FakeHttpClientAdapter adapter;

  setUp(() async {
    sessionStore = SessionStore.inMemory();
    await sessionStore.saveBaseUrl('https://api.example.com');
    await sessionStore.saveTokens(
      accessToken: 'access-token',
      refreshToken: 'refresh-token',
      expiresAt: DateTime.parse('2026-03-08T10:00:00Z'),
    );
    apiClient = ApiClient(sessionStore: sessionStore);
    playlistsApi = PlaylistsApi(apiClient: apiClient);
    adapter = FakeHttpClientAdapter();
    apiClient.rawDio.httpClientAdapter = adapter;
    apiClient.rawRefreshDio.httpClientAdapter = adapter;
  });

  tearDown(() {
    apiClient.dispose();
  });

  test('getPlaylists sends include_system query and parses response', () async {
    adapter.enqueueJson(
      method: 'GET',
      path: '/playlists',
      body: <Map<String, dynamic>>[
        <String, dynamic>{
          'id': 1,
          'name': '最近播放',
          'kind': 'recently_played',
          'description': '系统自动维护的最近播放影片列表',
          'is_system': true,
          'is_mutable': false,
          'is_deletable': false,
          'movie_count': 23,
          'created_at': '2026-03-12T10:00:00Z',
          'updated_at': '2026-03-12T10:00:00Z',
        },
      ],
    );

    final playlists = await playlistsApi.getPlaylists(includeSystem: true);

    final request = adapter.requests.single;
    expect(request.method, 'GET');
    expect(request.path, '/playlists');
    expect(request.uri.queryParameters['include_system'], 'true');
    expect(
      playlists.single,
      isA<PlaylistDto>()
          .having((value) => value.name, 'name', '最近播放')
          .having((value) => value.isSystem, 'isSystem', isTrue)
          .having((value) => value.movieCount, 'movieCount', 23),
    );
  });

  test('createPlaylist sends body and parses response', () async {
    adapter.enqueueJson(
      method: 'POST',
      path: '/playlists',
      statusCode: 201,
      body: <String, dynamic>{
        'id': 2,
        'name': '稍后再看',
        'kind': 'custom',
        'description': 'Need watch later',
        'is_system': false,
        'is_mutable': true,
        'is_deletable': true,
        'movie_count': 0,
        'created_at': '2026-03-12T10:10:00Z',
        'updated_at': '2026-03-12T10:10:00Z',
      },
    );

    final playlist = await playlistsApi.createPlaylist(
      name: '稍后再看',
      description: 'Need watch later',
    );

    final request = adapter.requests.single;
    expect(request.method, 'POST');
    expect(request.path, '/playlists');
    expect(request.body, <String, dynamic>{
      'name': '稍后再看',
      'kind': 'custom',
      'description': 'Need watch later',
    });
    expect(playlist.name, '稍后再看');
    expect(playlist.kind, 'custom');
    expect(playlist.isSystem, isFalse);
    expect(playlist.isSmart, isFalse);
  });

  test('createPlaylist sends smart filter snapshot', () async {
    adapter.enqueueJson(
      method: 'POST',
      path: '/playlists',
      statusCode: 201,
      body: <String, dynamic>{
        'id': 9,
        'name': '高分未看',
        'kind': 'smart',
        'description': '',
        'is_system': false,
        'is_mutable': true,
        'is_deletable': true,
        'is_smart': true,
        'smart_filter': <String, dynamic>{
          'watch_status': 'unwatched',
          'heat_min': 800,
        },
        'movie_count': 12,
        'created_at': '2026-03-12T10:10:00Z',
        'updated_at': '2026-03-12T10:10:00Z',
      },
    );

    final playlist = await playlistsApi.createPlaylist(
      name: '高分未看',
      kind: PlaylistKind.smart,
      smartFilter: <String, dynamic>{
        'watch_status': 'unwatched',
        'heat_min': 800,
      },
    );

    final request = adapter.requests.single;
    expect(request.body, <String, dynamic>{
      'name': '高分未看',
      'kind': 'smart',
      'filter': <String, dynamic>{'watch_status': 'unwatched', 'heat_min': 800},
    });
    expect(playlist.kind, PlaylistKind.smart);
    expect(playlist.isSmart, isTrue);
    expect(playlist.movieCount, 12);
  });

  test('createPlaylist converts conflict response to ApiException', () async {
    adapter.enqueueJson(
      method: 'POST',
      path: '/playlists',
      statusCode: 409,
      body: <String, dynamic>{
        'error': <String, dynamic>{
          'code': 'playlist_name_conflict',
          'message': '播放列表名称已存在',
        },
      },
    );

    expect(
      () => playlistsApi.createPlaylist(name: '最近播放'),
      throwsA(
        isA<ApiException>().having(
          (ApiException error) => error.error?.code,
          'error.code',
          'playlist_name_conflict',
        ),
      ),
    );
  });

  test('getPlaylistDetail parses playlist resource', () async {
    adapter.enqueueJson(
      method: 'GET',
      path: '/playlists/8',
      body: <String, dynamic>{
        'id': 8,
        'name': '我的收藏',
        'kind': 'custom',
        'description': 'Favorite movies',
        'is_system': false,
        'is_mutable': true,
        'is_deletable': true,
        'movie_count': 8,
        'created_at': '2026-03-12T10:10:00Z',
        'updated_at': '2026-03-12T11:20:00Z',
      },
    );

    final playlist = await playlistsApi.getPlaylistDetail(playlistId: 8);

    expect(playlist.id, 8);
    expect(playlist.movieCount, 8);
    expect(playlist.updatedAt, DateTime.parse('2026-03-12T11:20:00Z'));
  });

  test('getPlaylistDetail parses the smart filter snapshot', () async {
    adapter.enqueueJson(
      method: 'GET',
      path: '/playlists/9',
      body: <String, dynamic>{
        'id': 9,
        'name': '高分未看',
        'kind': 'smart',
        'description': '',
        'is_system': false,
        'is_mutable': true,
        'is_deletable': true,
        'is_smart': true,
        'smart_filter': <String, dynamic>{
          'statuses': <String>['subscribed', 'playable'],
          'status_match': 'and',
          'watch_statuses': <String>['unwatched'],
          'watch_match': 'or',
          'collection_type': 'single',
          'number_source': 'fc2',
          'sort': 'heat:desc',
          'years': <int>[2024],
          'resolutions': <String>['4K', '1080P'],
          'tag_ids': <int>[1, 2],
          'tag_match': 'and',
          'media_tag_ids': <int>[3],
          'media_tag_match': 'or',
          'actor_ids': <int>[7, 8],
          'actor_match': 'and',
          'actor_age_min': 20,
          'actor_age_max': 30,
          'heat_min': 100,
          'heat_max': 900,
        },
        'movie_count': 12,
        'created_at': '2026-03-12T10:10:00Z',
        'updated_at': '2026-03-12T10:10:00Z',
      },
    );

    final playlist = await playlistsApi.getPlaylistDetail(playlistId: 9);
    final smart = playlist.smartFilter;

    expect(playlist.isSmart, isTrue);
    expect(smart, isNotNull);
    expect(smart!.statuses, <String>['subscribed', 'playable']);
    expect(smart.statusMatch, 'and');
    expect(smart.watchStatuses, <String>['unwatched']);
    expect(smart.watchMatch, 'or');
    expect(smart.collectionType, 'single');
    expect(smart.numberSource, 'fc2');
    expect(smart.sort, 'heat:desc');
    expect(smart.years, <int>[2024]);
    expect(smart.resolutions, <String>['4K', '1080P']);
    expect(smart.tagIds, <int>[1, 2]);
    expect(smart.tagMatch, 'and');
    expect(smart.mediaTagIds, <int>[3]);
    expect(smart.actorIds, <int>[7, 8]);
    expect(smart.actorMatch, 'and');
    expect(smart.actorAgeMin, 20);
    expect(smart.actorAgeMax, 30);
    expect(smart.heatMin, 100);
    expect(smart.heatMax, 900);
  });

  test('smart filter keeps compatibility with legacy single values', () {
    final smart = SmartPlaylistFilterDto.fromJson(<String, dynamic>{
      'status': 'playable',
      'watch_status': 'unwatched',
      'resolution': '4K',
    });

    expect(smart.statuses, <String>['playable']);
    expect(smart.watchStatuses, <String>['unwatched']);
    expect(smart.resolutions, <String>['4K']);
  });

  test('updatePlaylist sends patch request and parses response', () async {
    adapter.enqueueJson(
      method: 'PATCH',
      path: '/playlists/8',
      body: <String, dynamic>{
        'id': 8,
        'name': '稍后再看',
        'kind': 'custom',
        'description': 'Need watch later',
        'is_system': false,
        'is_mutable': true,
        'is_deletable': true,
        'movie_count': 8,
        'created_at': '2026-03-12T10:10:00Z',
        'updated_at': '2026-03-12T11:30:00Z',
      },
    );

    final playlist = await playlistsApi.updatePlaylist(
      playlistId: 8,
      payload: const UpdatePlaylistPayload(
        name: '稍后再看',
        description: 'Need watch later',
      ),
    );

    final request = adapter.requests.single;
    expect(request.method, 'PATCH');
    expect(request.path, '/playlists/8');
    expect(request.body, <String, dynamic>{
      'name': '稍后再看',
      'description': 'Need watch later',
    });
    expect(playlist.name, '稍后再看');
    expect(playlist.updatedAt, DateTime.parse('2026-03-12T11:30:00Z'));
  });

  test('updatePlaylist converts conflict response to ApiException', () async {
    adapter.enqueueJson(
      method: 'PATCH',
      path: '/playlists/8',
      statusCode: 409,
      body: <String, dynamic>{
        'error': <String, dynamic>{
          'code': 'playlist_name_conflict',
          'message': '播放列表名称已存在',
        },
      },
    );

    expect(
      () => playlistsApi.updatePlaylist(
        playlistId: 8,
        payload: const UpdatePlaylistPayload(name: '最近播放'),
      ),
      throwsA(
        isA<ApiException>().having(
          (ApiException error) => error.error?.code,
          'error.code',
          'playlist_name_conflict',
        ),
      ),
    );
  });

  test('getPlaylistMovies parses paginated movie response', () async {
    adapter.enqueueJson(
      method: 'GET',
      path: '/playlists/8/movies',
      body: <String, dynamic>{
        'items': [
          <String, dynamic>{
            'movie_number': 'ABC-001',
            'title': 'Movie 1',
            'cover_image': null,
            'release_date': '2024-01-02',
            'duration_minutes': 120,
            'is_collection': true,
            'is_subscribed': false,
            'can_play': true,
            'playlist_item_updated_at': '2026-03-12T10:20:00Z',
          },
        ],
        'page': 1,
        'page_size': 20,
        'total': 1,
      },
    );

    final page = await playlistsApi.getPlaylistMovies(
      playlistId: 8,
      page: 1,
      pageSize: 20,
    );

    final request = adapter.requests.single;
    expect(request.method, 'GET');
    expect(request.path, '/playlists/8/movies');
    expect(request.uri.queryParameters['page'], '1');
    expect(request.uri.queryParameters['page_size'], '20');
    expect(page.items.single.movieNumber, 'ABC-001');
  });

  test('getPlaylistMovies sends temporary filter query params', () async {
    adapter.enqueueJson(
      method: 'GET',
      path: '/playlists/8/movies',
      body: <String, dynamic>{
        'items': <Map<String, dynamic>>[],
        'page': 1,
        'page_size': 20,
        'total': 0,
      },
    );

    final page = await playlistsApi.getPlaylistMovies(
      playlistId: 8,
      sort: 'heat:desc',
      statuses: const <String>['playable', 'subscribed'],
      statusMatch: 'and',
      watchStatuses: const <String>['unwatched'],
      watchMatch: 'or',
      years: const <int>[2024, 2023],
      resolutions: const <String>['4K', '1080P'],
      tagIds: const <int>[1, 2],
      tagMatch: 'and',
      mediaTagIds: const <int>[3],
      mediaTagMatch: 'or',
    );

    final request = adapter.requests.single;
    expect(request.uri.queryParameters['sort'], 'heat:desc');
    expect(request.uri.queryParameters['statuses'], 'playable,subscribed');
    expect(request.uri.queryParameters['status_match'], 'and');
    expect(request.uri.queryParameters['watch_statuses'], 'unwatched');
    expect(request.uri.queryParameters['watch_match'], 'or');
    expect(request.uri.queryParameters['year'], '2024,2023');
    expect(request.uri.queryParameters['resolutions'], '4K,1080P');
    expect(request.uri.queryParameters['tag_ids'], '1,2');
    expect(request.uri.queryParameters['tag_match'], 'and');
    expect(request.uri.queryParameters['media_tag_ids'], '3');
    expect(request.uri.queryParameters['media_tag_match'], 'or');
    expect(page.total, 0);
  });

  test('getPlaylistMovies preserves explicit empty override params', () async {
    adapter.enqueueJson(
      method: 'GET',
      path: '/playlists/8/movies',
      body: <String, dynamic>{
        'items': <Map<String, dynamic>>[],
        'page': 1,
        'page_size': 20,
        'total': 0,
      },
    );

    await playlistsApi.getPlaylistMovies(
      playlistId: 8,
      statuses: const <String>[],
      watchStatuses: const <String>[],
      years: const <int>[],
      resolutions: const <String>[],
      tagIds: const <int>[],
      mediaTagIds: const <int>[],
    );

    final query = adapter.requests.single.uri.queryParameters;
    expect(query['statuses'], '');
    expect(query['watch_statuses'], '');
    expect(query['year'], '');
    expect(query['resolutions'], '');
    expect(query['tag_ids'], '');
    expect(query['media_tag_ids'], '');
  });

  test('addMovieToPlaylist sends put request', () async {
    adapter.enqueueJson(
      method: 'PUT',
      path: '/playlists/8/movies/ABC-001',
      statusCode: 204,
    );

    await playlistsApi.addMovieToPlaylist(
      playlistId: 8,
      movieNumber: 'ABC-001',
    );

    final request = adapter.requests.single;
    expect(request.method, 'PUT');
    expect(request.path, '/playlists/8/movies/ABC-001');
  });

  test(
    'addMoviesToPlaylist posts all numbers and parses skipped items',
    () async {
      adapter.enqueueJson(
        method: 'POST',
        path: '/playlists/8/movies',
        body: <String, dynamic>{
          'requested_count': 3,
          'updated_count': 2,
          'skipped_count': 1,
          'skipped': <Map<String, dynamic>>[
            <String, dynamic>{
              'movie_number': 'MISSING-001',
              'reason': 'movie_not_found',
            },
          ],
        },
      );

      final result = await playlistsApi.addMoviesToPlaylist(
        playlistId: 8,
        movieNumbers: const <String>['ABC-001', 'ABC-002', 'MISSING-001'],
      );

      final request = adapter.requests.single;
      expect(request.method, 'POST');
      expect(request.path, '/playlists/8/movies');
      expect(request.body, <String, dynamic>{
        'movie_numbers': <String>['ABC-001', 'ABC-002', 'MISSING-001'],
      });
      expect(result.requestedCount, 3);
      expect(result.updatedCount, 2);
      expect(result.skippedCount, 1);
      expect(result.skipped.single.movieNumber, 'MISSING-001');
      expect(result.skipped.single.reason, 'movie_not_found');
    },
  );

  test('removeMovieFromPlaylist sends delete request', () async {
    adapter.enqueueJson(
      method: 'DELETE',
      path: '/playlists/8/movies/ABC-001',
      statusCode: 204,
    );

    await playlistsApi.removeMovieFromPlaylist(
      playlistId: 8,
      movieNumber: 'ABC-001',
    );

    final request = adapter.requests.single;
    expect(request.method, 'DELETE');
    expect(request.path, '/playlists/8/movies/ABC-001');
  });

  test('deletePlaylist sends delete request', () async {
    adapter.enqueueJson(
      method: 'DELETE',
      path: '/playlists/8',
      statusCode: 204,
    );

    await playlistsApi.deletePlaylist(8);

    final request = adapter.requests.single;
    expect(request.method, 'DELETE');
    expect(request.path, '/playlists/8');
  });
}
