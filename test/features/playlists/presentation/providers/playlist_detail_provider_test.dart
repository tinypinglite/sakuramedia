import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sakuramedia/core/network/api_client.dart';
import 'package:sakuramedia/core/session/session_store.dart';
import 'package:sakuramedia/features/playlists/data/api/playlists_api.dart';
import 'package:sakuramedia/features/playlists/presentation/providers/playlist_detail_provider.dart';
import 'package:sakuramedia/features/playlists/presentation/providers/playlists_api_provider.dart';
import 'package:sakuramedia/l10n/app_localizations_zh.dart';

import '../../../../support/fake_http_client_adapter.dart';

void main() {
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
      expiresAt: DateTime.parse('2026-08-04T12:00:00Z'),
    );
    apiClient = ApiClient(sessionStore: sessionStore);
    adapter = FakeHttpClientAdapter();
    apiClient.rawDio.httpClientAdapter = adapter;
    apiClient.rawRefreshDio.httpClientAdapter = adapter;
    container = ProviderContainer(
      overrides: [
        playlistsApiProvider.overrideWithValue(
          PlaylistsApi(apiClient: apiClient),
        ),
      ],
      retry: (_, __) => null,
    );
  });

  tearDown(() {
    container.dispose();
    apiClient.dispose();
    sessionStore.dispose();
  });

  void keepAlive(int playlistId) {
    final subscription = container.listen(
      playlistDetailProvider(playlistId),
      (_, __) {},
    );
    addTearDown(subscription.close);
  }

  Map<String, dynamic> _playlistJson({
    required int id,
    String name = '播放列表',
    int movieCount = 42,
  }) => <String, dynamic>{
        'id': id,
        'name': name,
        'description': '',
        'movie_count': movieCount,
        'is_system': false,
        'is_mutable': true,
        'is_deletable': true,
        'created_at': '2026-01-01T00:00:00Z',
        'updated_at': '2026-01-01T00:00:00Z',
      };

  test('build fetches playlist detail', () async {
    adapter.enqueueJson(
      method: 'GET',
      path: '/playlists/8',
      body: _playlistJson(id: 8, name: '精选'),
    );

    keepAlive(8);
    final playlist = await container.read(playlistDetailProvider(8).future);

    expect(playlist.id, 8);
    expect(playlist.name, '精选');
  });

  test('refresh reloads detail', () async {
    adapter.enqueueJson(
      method: 'GET',
      path: '/playlists/8',
      body: _playlistJson(id: 8, name: '精选', movieCount: 10),
    );
    adapter.enqueueJson(
      method: 'GET',
      path: '/playlists/8',
      body: _playlistJson(id: 8, name: '改名', movieCount: 20),
    );

    keepAlive(8);
    await container.read(playlistDetailProvider(8).future);
    await container.read(playlistDetailProvider(8).notifier).refresh();

    final state = container.read(playlistDetailProvider(8)).requireValue;
    expect(state.name, '改名');
    expect(state.movieCount, 20);
  });

  test('build surfaces 404 error path', () async {
    adapter.enqueueJson(
      method: 'GET',
      path: '/playlists/999',
      statusCode: 404,
      body: <String, dynamic>{
        'error': <String, dynamic>{
          'code': 'playlist_not_found',
          'message': 'not found',
        },
      },
    );

    keepAlive(999);
    try {
      await container.read(playlistDetailProvider(999).future);
      fail('expected an error');
    } catch (error) {
      expect(
        playlistDetailErrorMessage(error, l10n: AppLocalizationsZh()),
        '未找到该播放列表',
      );
    }
  });
}
