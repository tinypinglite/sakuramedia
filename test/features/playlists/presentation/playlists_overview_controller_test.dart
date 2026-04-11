import 'package:flutter_test/flutter_test.dart';
import 'package:sakuramedia/features/playlists/data/playlist_dto.dart';
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
