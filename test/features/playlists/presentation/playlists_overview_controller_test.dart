import 'package:flutter_test/flutter_test.dart';
import 'package:sakuramedia/features/playlists/data/playlist_dto.dart';
import 'package:sakuramedia/features/playlists/data/playlist_order_store.dart';
import 'package:sakuramedia/features/playlists/presentation/playlists_overview_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PlaylistsOverviewController', () {
    test('refresh replaces playlists and cover urls', () async {
      var cycle = 0;
      final controller = PlaylistsOverviewController(
        fetchPlaylists: ({includeSystem = false}) async {
          cycle += 1;
          if (cycle == 1) {
            return <PlaylistDto>[_playlist(1, 'Old', movieCount: 0)];
          }
          return <PlaylistDto>[_playlist(2, 'New', movieCount: 1)];
        },
        fetchPlaylistCoverUrl: (playlistId) async => '/covers/$playlistId.jpg',
        createPlaylist:
            ({required String name, String? description}) async =>
                _playlist(3, name, movieCount: 0),
      );

      await controller.load();
      await controller.refresh();

      expect(controller.playlists.single.id, 2);
      expect(controller.playlists.single.name, 'New');
      expect(controller.coverUrlFor(1), isNull);
      expect(controller.coverUrlFor(2), '/covers/2.jpg');
      expect(controller.errorMessage, isNull);
    });

    test('refresh rethrows and keeps existing playlists on failure', () async {
      var cycle = 0;
      final controller = PlaylistsOverviewController(
        fetchPlaylists: ({includeSystem = false}) async {
          cycle += 1;
          if (cycle == 1) {
            return <PlaylistDto>[_playlist(1, 'Old', movieCount: 1)];
          }
          throw Exception('refresh failed');
        },
        fetchPlaylistCoverUrl: (playlistId) async => '/covers/$playlistId.jpg',
        createPlaylist:
            ({required String name, String? description}) async =>
                _playlist(3, name, movieCount: 0),
      );

      await controller.load();

      await expectLater(controller.refresh(), throwsException);

      expect(controller.playlists.single.id, 1);
      expect(controller.playlists.single.name, 'Old');
      expect(controller.coverUrlFor(1), '/covers/1.jpg');
      expect(controller.errorMessage, isNull);
    });

    test(
      'load applies local order and appends unseen playlists to end',
      () async {
        final orderStore = InMemoryPlaylistOrderStore();
        await orderStore.savePlaylistOrder(
          scopeKey: 'https://api.example.com',
          playlistIds: <int>[2, 1, 99],
        );
        final controller = PlaylistsOverviewController(
          fetchPlaylists: ({includeSystem = false}) async {
            return <PlaylistDto>[
              _playlist(1, 'P1', movieCount: 0),
              _playlist(2, 'P2', movieCount: 0),
              _playlist(3, 'P3', movieCount: 0),
            ];
          },
          fetchPlaylistCoverUrl:
              (playlistId) async => '/covers/$playlistId.jpg',
          createPlaylist:
              ({required String name, String? description}) async =>
                  _playlist(4, name, movieCount: 0),
          playlistOrderStore: orderStore,
          orderScopeKey: 'https://api.example.com',
        );

        await controller.load();

        expect(
          controller.playlists.map((playlist) => playlist.id).toList(),
          <int>[2, 1, 3],
        );
        expect(
          await orderStore.readPlaylistOrder(
            scopeKey: 'https://api.example.com',
          ),
          <int>[2, 1, 3],
        );
      },
    );

    test(
      'refresh keeps local order and appends newly fetched playlists',
      () async {
        final orderStore = InMemoryPlaylistOrderStore();
        await orderStore.savePlaylistOrder(
          scopeKey: 'https://api.example.com',
          playlistIds: <int>[2, 1],
        );
        var cycle = 0;
        final controller = PlaylistsOverviewController(
          fetchPlaylists: ({includeSystem = false}) async {
            cycle += 1;
            if (cycle == 1) {
              return <PlaylistDto>[
                _playlist(1, 'Old-1', movieCount: 0),
                _playlist(2, 'Old-2', movieCount: 0),
              ];
            }
            return <PlaylistDto>[
              _playlist(1, 'New-1', movieCount: 0),
              _playlist(3, 'New-3', movieCount: 0),
              _playlist(2, 'New-2', movieCount: 0),
            ];
          },
          fetchPlaylistCoverUrl:
              (playlistId) async => '/covers/$playlistId.jpg',
          createPlaylist:
              ({required String name, String? description}) async =>
                  _playlist(4, name, movieCount: 0),
          playlistOrderStore: orderStore,
          orderScopeKey: 'https://api.example.com',
        );

        await controller.load();
        await controller.refresh();

        expect(
          controller.playlists.map((playlist) => playlist.id).toList(),
          <int>[2, 1, 3],
        );
        expect(
          await orderStore.readPlaylistOrder(
            scopeKey: 'https://api.example.com',
          ),
          <int>[2, 1, 3],
        );
      },
    );

    test('reorderPlaylists updates in-memory order and persists it', () async {
      final orderStore = InMemoryPlaylistOrderStore();
      final controller = PlaylistsOverviewController(
        fetchPlaylists: ({includeSystem = false}) async {
          return <PlaylistDto>[
            _playlist(1, 'P1', movieCount: 0),
            _playlist(2, 'P2', movieCount: 0),
            _playlist(3, 'P3', movieCount: 0),
          ];
        },
        fetchPlaylistCoverUrl: (playlistId) async => '/covers/$playlistId.jpg',
        createPlaylist:
            ({required String name, String? description}) async =>
                _playlist(4, name, movieCount: 0),
        playlistOrderStore: orderStore,
        orderScopeKey: 'https://api.example.com',
      );

      await controller.load();
      controller.reorderPlaylists(0, 3);
      await Future<void>.delayed(Duration.zero);

      expect(
        controller.playlists.map((playlist) => playlist.id).toList(),
        <int>[2, 3, 1],
      );
      expect(
        await orderStore.readPlaylistOrder(scopeKey: 'https://api.example.com'),
        <int>[2, 3, 1],
      );
    });
  });
}

PlaylistDto _playlist(int id, String name, {required int movieCount}) {
  return PlaylistDto(
    id: id,
    name: name,
    kind: 'custom',
    description: '',
    isSystem: false,
    isMutable: true,
    isDeletable: true,
    movieCount: movieCount,
    createdAt: DateTime.parse('2026-03-12T10:00:00Z'),
    updatedAt: DateTime.parse('2026-03-12T10:00:00Z'),
  );
}
