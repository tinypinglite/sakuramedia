import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sakuramedia/core/network/api_client.dart';
import 'package:sakuramedia/core/session/session_store.dart';
import 'package:sakuramedia/features/playlists/data/api/playlists_api.dart';
import 'package:sakuramedia/features/playlists/data/dto/playlist_dto.dart';
import 'package:sakuramedia/features/playlists/data/playlist_order_store.dart';
import 'package:sakuramedia/features/playlists/presentation/providers/playlist_mutation_events_provider.dart';
import 'package:sakuramedia/features/playlists/presentation/providers/playlist_order_store_provider.dart';
import 'package:sakuramedia/features/playlists/presentation/providers/playlists_api_provider.dart';
import 'package:sakuramedia/features/playlists/presentation/providers/playlists_overview_provider.dart';
import 'package:sakuramedia/features/playlists/presentation/providers/playlists_overview_scope.dart';

import '../../../../support/fake_http_client_adapter.dart';

const PlaylistsOverviewScope _scopeWithOrder = PlaylistsOverviewScope(
  orderScopeKey: 'test',
);
const PlaylistsOverviewScope _scopeNoOrder = PlaylistsOverviewScope();

void main() {
  late SessionStore sessionStore;
  late ApiClient apiClient;
  late FakeHttpClientAdapter adapter;
  late InMemoryPlaylistOrderStore orderStore;
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
    orderStore = InMemoryPlaylistOrderStore();
    container = ProviderContainer(
      overrides: [
        playlistsApiProvider.overrideWithValue(
          PlaylistsApi(apiClient: apiClient),
        ),
        playlistOrderStoreProvider.overrideWithValue(orderStore),
      ],
      retry: (_, __) => null,
    );
  });

  tearDown(() {
    container.dispose();
    apiClient.dispose();
    sessionStore.dispose();
  });

  void keepAlive(PlaylistsOverviewScope scope) {
    final subscription = container.listen(
      playlistsOverviewProvider(scope),
      (_, __) {},
    );
    addTearDown(subscription.close);
  }

  Map<String, dynamic> _playlistJson({
    required int id,
    required String name,
    int movieCount = 0,
    bool isSystem = false,
  }) => <String, dynamic>{
    'id': id,
    'name': name,
    'description': '',
    'movie_count': movieCount,
    'is_system': isSystem,
    'is_mutable': !isSystem,
    'is_deletable': !isSystem,
    'created_at': '2026-01-01T00:00:00Z',
    'updated_at': '2026-01-01T00:00:00Z',
  };

  test('build fetches playlists including system lists', () async {
    adapter.enqueueJson(
      method: 'GET',
      path: '/playlists',
      body: <Map<String, dynamic>>[
        _playlistJson(id: 1, name: 'Alpha', movieCount: 0),
        _playlistJson(id: 2, name: 'Beta', movieCount: 0),
      ],
    );

    keepAlive(_scopeNoOrder);
    final state = await container.read(
      playlistsOverviewProvider(_scopeNoOrder).future,
    );

    expect(state.playlists.map((p) => p.id), <int>[1, 2]);
    expect(
      adapter.requests.single.uri.queryParameters['include_system'],
      'true',
    );
  });

  test('build applies stored order when orderScopeKey is set', () async {
    // Persist a prior order [2, 1] under the same scopeKey.
    await orderStore.savePlaylistOrder(
      scopeKey: 'test',
      playlistIds: <int>[2, 1],
    );
    adapter.enqueueJson(
      method: 'GET',
      path: '/playlists',
      body: <Map<String, dynamic>>[
        _playlistJson(id: 1, name: 'Alpha'),
        _playlistJson(id: 2, name: 'Beta'),
      ],
    );

    keepAlive(_scopeWithOrder);
    final state = await container.read(
      playlistsOverviewProvider(_scopeWithOrder).future,
    );

    expect(state.playlists.map((p) => p.id), <int>[2, 1]);
  });

  test('reorderPlaylists mutates local order and persists it', () async {
    adapter.enqueueJson(
      method: 'GET',
      path: '/playlists',
      body: <Map<String, dynamic>>[
        _playlistJson(id: 10, name: 'A'),
        _playlistJson(id: 11, name: 'B'),
        _playlistJson(id: 12, name: 'C'),
      ],
    );

    keepAlive(_scopeWithOrder);
    await container.read(playlistsOverviewProvider(_scopeWithOrder).future);

    container
        .read(playlistsOverviewProvider(_scopeWithOrder).notifier)
        .reorderPlaylists(0, 1);
    // 让 fire-and-forget 的 _savePlaylistOrder 有机会跑完。
    await Future<void>.delayed(Duration.zero);

    final state = container
        .read(playlistsOverviewProvider(_scopeWithOrder))
        .requireValue;
    expect(state.playlists.map((p) => p.id), <int>[11, 10, 12]);
    expect(orderStore.snapshot['test'], <int>[11, 10, 12]);
  });

  test('reorderCustomPlaylists only moves custom playlists', () async {
    adapter.enqueueJson(
      method: 'GET',
      path: '/playlists',
      body: <Map<String, dynamic>>[
        _playlistJson(id: 10, name: 'A'),
        _playlistJson(id: 1, name: 'Favorites', isSystem: true),
        _playlistJson(id: 11, name: 'B'),
        _playlistJson(id: 12, name: 'C'),
      ],
    );

    keepAlive(_scopeWithOrder);
    await container.read(playlistsOverviewProvider(_scopeWithOrder).future);

    container
        .read(playlistsOverviewProvider(_scopeWithOrder).notifier)
        .reorderCustomPlaylists(0, 2);
    await Future<void>.delayed(Duration.zero);

    final state = container
        .read(playlistsOverviewProvider(_scopeWithOrder))
        .requireValue;
    // 系统列表仍在原槽位；用户列表 A 移到用户列表末尾。
    expect(state.playlists.map((p) => p.id), <int>[11, 1, 12, 10]);
    expect(orderStore.snapshot['test'], <int>[11, 1, 12, 10]);
  });

  test('insertPlaylist prepends and persists new order', () async {
    adapter.enqueueJson(
      method: 'GET',
      path: '/playlists',
      body: <Map<String, dynamic>>[_playlistJson(id: 10, name: 'A')],
    );

    keepAlive(_scopeWithOrder);
    await container.read(playlistsOverviewProvider(_scopeWithOrder).future);

    final playlist = PlaylistDto.fromJson(_playlistJson(id: 99, name: 'New'));
    container
        .read(playlistsOverviewProvider(_scopeWithOrder).notifier)
        .insertPlaylist(playlist);
    await Future<void>.delayed(Duration.zero);

    final state = container
        .read(playlistsOverviewProvider(_scopeWithOrder))
        .requireValue;
    expect(state.playlists.map((p) => p.id), <int>[99, 10]);
    expect(orderStore.snapshot['test'], <int>[99, 10]);
  });

  test('removePlaylist drops the playlist and persists new order', () async {
    adapter.enqueueJson(
      method: 'GET',
      path: '/playlists',
      body: <Map<String, dynamic>>[
        _playlistJson(id: 10, name: 'A'),
        _playlistJson(id: 11, name: 'B'),
      ],
    );

    keepAlive(_scopeWithOrder);
    await container.read(playlistsOverviewProvider(_scopeWithOrder).future);

    container
        .read(playlistsOverviewProvider(_scopeWithOrder).notifier)
        .removePlaylist(10);
    await Future<void>.delayed(Duration.zero);

    final state = container
        .read(playlistsOverviewProvider(_scopeWithOrder))
        .requireValue;
    expect(state.playlists.map((p) => p.id), <int>[11]);
    expect(orderStore.snapshot['test'], <int>[11]);
  });

  test('scope without orderScopeKey does not touch persistence', () async {
    adapter.enqueueJson(
      method: 'GET',
      path: '/playlists',
      body: <Map<String, dynamic>>[
        _playlistJson(id: 10, name: 'A'),
        _playlistJson(id: 11, name: 'B'),
      ],
    );

    keepAlive(_scopeNoOrder);
    await container.read(playlistsOverviewProvider(_scopeNoOrder).future);

    container
        .read(playlistsOverviewProvider(_scopeNoOrder).notifier)
        .reorderPlaylists(0, 1);
    await Future<void>.delayed(Duration.zero);

    // 未持久化任何 scope 的顺序。
    expect(orderStore.snapshot, isEmpty);
  });

  test(
    'mutation broadcast patches updated and deleted entries in place',
    () async {
      adapter.enqueueJson(
        method: 'GET',
        path: '/playlists',
        body: <Map<String, dynamic>>[
          _playlistJson(id: 10, name: 'A'),
          _playlistJson(id: 11, name: 'B'),
        ],
      );

      keepAlive(_scopeWithOrder);
      await container.read(playlistsOverviewProvider(_scopeWithOrder).future);

      final events = container.read(playlistMutationEventsProvider.notifier);
      events.reportUpdated(
        PlaylistDto.fromJson(_playlistJson(id: 11, name: 'B2')),
      );
      var state = container
          .read(playlistsOverviewProvider(_scopeWithOrder))
          .requireValue;
      expect(state.playlists.map((p) => p.name), <String>['A', 'B2']);

      events.reportDeleted(10);
      state = container
          .read(playlistsOverviewProvider(_scopeWithOrder))
          .requireValue;
      expect(state.playlists.map((p) => p.id), <int>[11]);
    },
  );

  test(
    'refresh keeps valid covers while it rechecks every non-empty playlist',
    () async {
      adapter.enqueueJson(
        method: 'GET',
        path: '/playlists',
        body: <Map<String, dynamic>>[
          _playlistJson(id: 10, name: 'A', movieCount: 1),
          _playlistJson(id: 11, name: 'Deleted', movieCount: 1),
          _playlistJson(id: 12, name: 'Becomes empty', movieCount: 1),
        ],
      );
      adapter.enqueueJson(
        method: 'GET',
        path: '/playlists/10/movies',
        body: _moviesPage('/covers/old-10.jpg'),
      );
      adapter.enqueueJson(
        method: 'GET',
        path: '/playlists/11/movies',
        body: _moviesPage('/covers/old-11.jpg'),
      );
      adapter.enqueueJson(
        method: 'GET',
        path: '/playlists/12/movies',
        body: _moviesPage('/covers/old-12.jpg'),
      );
      adapter.enqueueJson(
        method: 'GET',
        path: '/playlists',
        body: <Map<String, dynamic>>[
          _playlistJson(id: 10, name: 'A', movieCount: 1),
          _playlistJson(id: 12, name: 'Becomes empty', movieCount: 0),
          _playlistJson(id: 20, name: 'New', movieCount: 1),
        ],
      );
      final refreshedCover = Completer<ResponseBody>();
      adapter.enqueueResponder(
        method: 'GET',
        path: '/playlists/10/movies',
        responder: (_, __) => refreshedCover.future,
      );
      adapter.enqueueJson(
        method: 'GET',
        path: '/playlists/20/movies',
        body: _moviesPage('/covers/new-20.jpg'),
      );

      keepAlive(_scopeNoOrder);
      await container.read(playlistsOverviewProvider(_scopeNoOrder).future);
      await pumpEventQueue();
      expect(
        container
            .read(playlistsOverviewProvider(_scopeNoOrder))
            .requireValue
            .coverUrlFor(10),
        '/covers/old-10.jpg',
      );

      await container
          .read(playlistsOverviewProvider(_scopeNoOrder).notifier)
          .refresh();

      final retainedState = container
          .read(playlistsOverviewProvider(_scopeNoOrder))
          .requireValue;
      expect(retainedState.playlists.map((p) => p.id), <int>[10, 12, 20]);
      expect(retainedState.coverUrlFor(10), '/covers/old-10.jpg');
      expect(retainedState.coverUrlFor(20), isNull);
      expect(retainedState.coverUrlFor(12), isNull);
      expect(retainedState.coverUrls.containsKey(11), isFalse);

      refreshedCover.complete(_jsonResponse(_moviesPage('/covers/new-10.jpg')));
      await pumpEventQueue();

      final refreshedState = container
          .read(playlistsOverviewProvider(_scopeNoOrder))
          .requireValue;
      expect(refreshedState.coverUrlFor(10), '/covers/new-10.jpg');
      expect(refreshedState.coverUrlFor(20), '/covers/new-20.jpg');
      expect(refreshedState.coverUrlFor(12), isNull);
      expect(refreshedState.coverUrls.containsKey(11), isFalse);
      expect(adapter.hitCount('GET', '/playlists/11/movies'), 1);
      expect(adapter.hitCount('GET', '/playlists/12/movies'), 1);
    },
  );

  test(
    'refresh retains an old cover after a failed request but clears empty results',
    () async {
      adapter.enqueueJson(
        method: 'GET',
        path: '/playlists',
        body: <Map<String, dynamic>>[
          _playlistJson(id: 10, name: 'A', movieCount: 1),
        ],
      );
      adapter.enqueueJson(
        method: 'GET',
        path: '/playlists/10/movies',
        body: _moviesPage('/covers/old-10.jpg'),
      );
      adapter.enqueueJson(
        method: 'GET',
        path: '/playlists',
        body: <Map<String, dynamic>>[
          _playlistJson(id: 10, name: 'A', movieCount: 1),
        ],
      );
      adapter.enqueueJson(
        method: 'GET',
        path: '/playlists/10/movies',
        statusCode: 500,
        body: <String, dynamic>{'detail': 'temporary failure'},
      );
      adapter.enqueueJson(
        method: 'GET',
        path: '/playlists',
        body: <Map<String, dynamic>>[
          _playlistJson(id: 10, name: 'A', movieCount: 1),
        ],
      );
      adapter.enqueueJson(
        method: 'GET',
        path: '/playlists/10/movies',
        body: _emptyMoviesPage(),
      );

      keepAlive(_scopeNoOrder);
      await container.read(playlistsOverviewProvider(_scopeNoOrder).future);
      await pumpEventQueue();
      expect(
        container
            .read(playlistsOverviewProvider(_scopeNoOrder))
            .requireValue
            .coverUrlFor(10),
        '/covers/old-10.jpg',
      );

      final notifier = container.read(
        playlistsOverviewProvider(_scopeNoOrder).notifier,
      );
      await notifier.refresh();
      await pumpEventQueue();
      expect(adapter.hitCount('GET', '/playlists/10/movies'), 2);
      expect(
        container
            .read(playlistsOverviewProvider(_scopeNoOrder))
            .requireValue
            .coverUrlFor(10),
        '/covers/old-10.jpg',
      );

      await notifier.refresh();
      await pumpEventQueue();
      expect(adapter.hitCount('GET', '/playlists/10/movies'), 3);
      expect(
        container
            .read(playlistsOverviewProvider(_scopeNoOrder))
            .requireValue
            .coverUrlFor(10),
        isNull,
      );
    },
  );

  test('refresh rethrows and keeps existing playlists on failure', () async {
    adapter.enqueueJson(
      method: 'GET',
      path: '/playlists',
      body: <Map<String, dynamic>>[_playlistJson(id: 10, name: 'A')],
    );
    adapter.enqueueJson(
      method: 'GET',
      path: '/playlists',
      statusCode: 500,
      body: <String, dynamic>{'detail': 'boom'},
    );

    keepAlive(_scopeNoOrder);
    await container.read(playlistsOverviewProvider(_scopeNoOrder).future);

    await expectLater(
      container
          .read(playlistsOverviewProvider(_scopeNoOrder).notifier)
          .refresh(),
      throwsA(anything),
    );

    // 失败后已展示列表必须保留（state 原样不动）——页面据 value != null
    // 继续渲染列表而非整页错误空态；失败提示由调用方 catch 后 toast。
    final async = container.read(playlistsOverviewProvider(_scopeNoOrder));
    expect(async.hasError, isFalse);
    expect(async.value?.playlists.map((p) => p.id), <int>[10]);
  });
}

Map<String, dynamic> _moviesPage(String coverUrl) => <String, dynamic>{
  'items': <Map<String, dynamic>>[
    <String, dynamic>{
      'movie_number': 'ABC-001',
      'cover_image': <String, dynamic>{'id': 1, 'origin': coverUrl},
    },
  ],
  'page': 1,
  'page_size': 1,
  'total': 1,
};

Map<String, dynamic> _emptyMoviesPage() => <String, dynamic>{
  'items': const <Map<String, dynamic>>[],
  'page': 1,
  'page_size': 1,
  'total': 0,
};

ResponseBody _jsonResponse(Map<String, dynamic> body) =>
    ResponseBody.fromString(
      jsonEncode(body),
      200,
      headers: const <String, List<String>>{
        Headers.contentTypeHeader: <String>[Headers.jsonContentType],
      },
    );
