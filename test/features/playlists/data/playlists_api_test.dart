import 'package:flutter_test/flutter_test.dart';
import 'package:sakuramedia/core/network/api_client.dart';
import 'package:sakuramedia/core/network/api_exception.dart';
import 'package:sakuramedia/core/session/session_store.dart';
import 'package:sakuramedia/features/playlists/data/playlist_dto.dart';
import 'package:sakuramedia/features/playlists/data/playlists_api.dart';

import '../../../support/fake_http_client_adapter.dart';

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
      'description': 'Need watch later',
    });
    expect(playlist.name, '稍后再看');
    expect(playlist.kind, 'custom');
    expect(playlist.isSystem, isFalse);
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

  test('getPlaylistMovies parses paginated movie response', () async {
    adapter.enqueueJson(
      method: 'GET',
      path: '/playlists/8/movies',
      body: <String, dynamic>{
        'items': [
          <String, dynamic>{
            'javdb_id': 'MovieA1',
            'movie_number': 'ABC-001',
            'title': 'Movie 1',
            'cover_image': null,
            'release_date': '2024-01-02',
            'duration_minutes': 120,
            'score': 4.5,
            'watched_count': 0,
            'want_watch_count': 0,
            'comment_count': 0,
            'score_number': 0,
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
}
