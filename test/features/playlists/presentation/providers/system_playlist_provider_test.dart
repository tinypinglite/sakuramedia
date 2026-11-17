import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sakuramedia/core/network/api_client.dart';
import 'package:sakuramedia/core/network/providers/api_client_provider.dart';
import 'package:sakuramedia/core/session/session_store.dart';
import 'package:sakuramedia/features/playlists/data/dto/playlist_dto.dart';
import 'package:sakuramedia/features/playlists/presentation/providers/system_playlist_provider.dart';

import '../../../../support/fake_http_client_adapter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SessionStore sessionStore;
  late ApiClient apiClient;
  late FakeHttpClientAdapter adapter;
  late ProviderContainer container;

  setUp(() async {
    sessionStore = SessionStore.inMemory();
    await sessionStore.saveBaseUrl('https://api.example.com');
    await sessionStore.saveTokens(
      accessToken: 'access-token',
      refreshToken: 'refresh-token',
      expiresAt: DateTime.parse('2026-08-04T10:00:00Z'),
    );
    apiClient = ApiClient(sessionStore: sessionStore);
    adapter = FakeHttpClientAdapter();
    apiClient.rawDio.httpClientAdapter = adapter;
    apiClient.rawRefreshDio.httpClientAdapter = adapter;
    container = ProviderContainer(
      overrides: [apiClientProvider.overrideWithValue(apiClient)],
      retry: (_, _) => null,
    );
  });

  tearDown(() {
    container.dispose();
    apiClient.dispose();
    sessionStore.dispose();
  });

  test('返回指定 kind 的系统列表', () async {
    adapter.enqueueJson(
      method: 'GET',
      path: '/playlists',
      body: <dynamic>[
        _playlistJson(id: 1, name: '我的列表', kind: 'custom'),
        _playlistJson(id: 8, name: '收藏', kind: PlaylistKind.favorites),
        _playlistJson(id: 9, name: '最近播放', kind: PlaylistKind.recentlyPlayed),
      ],
    );

    final playlist = await container.read(
      systemPlaylistProvider(PlaylistKind.recentlyPlayed).future,
    );

    expect(playlist?.id, 9);
    expect(playlist?.movieCount, 12);
    expect(
      adapter.requests.single.uri.queryParameters['include_system'],
      'true',
    );
  });

  test('按 favorites kind 返回收藏列表', () async {
    adapter.enqueueJson(
      method: 'GET',
      path: '/playlists',
      body: <dynamic>[
        _playlistJson(id: 8, name: '收藏', kind: PlaylistKind.favorites),
        _playlistJson(id: 9, name: '最近播放', kind: PlaylistKind.recentlyPlayed),
      ],
    );

    final playlist = await container.read(
      systemPlaylistProvider(PlaylistKind.favorites).future,
    );

    expect(playlist?.id, 8);
  });

  test('没有该系统列表时返回 null', () async {
    adapter.enqueueJson(
      method: 'GET',
      path: '/playlists',
      body: <dynamic>[_playlistJson(id: 1, name: '我的列表', kind: 'custom')],
    );

    final playlist = await container.read(
      systemPlaylistProvider(PlaylistKind.recentlyPlayed).future,
    );

    expect(playlist, isNull);
  });
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
    'is_system': kind != 'custom',
    'is_mutable': kind == 'custom',
    'is_deletable': kind == 'custom',
    'movie_count': 12,
    'created_at': '2026-01-01T00:00:00Z',
    'updated_at': '2026-01-02T00:00:00Z',
  };
}
