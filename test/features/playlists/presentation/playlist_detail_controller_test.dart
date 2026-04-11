import 'package:flutter_test/flutter_test.dart';
import 'package:sakuramedia/features/playlists/data/playlist_dto.dart';
import 'package:sakuramedia/features/playlists/presentation/playlist_detail_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PlaylistDetailController', () {
    test('refresh updates playlist detail after initial load', () async {
      var cycle = 0;
      final controller = PlaylistDetailController(
        playlistId: 8,
        fetchPlaylistDetail: ({required playlistId}) async {
          cycle += 1;
          return _playlist(cycle == 1 ? 'Old playlist' : 'New playlist');
        },
      );

      await controller.load();
      await controller.refresh();

      expect(controller.playlist?.name, 'New playlist');
      expect(controller.errorMessage, isNull);
    });

    test('refresh rethrows and keeps existing playlist on failure', () async {
      var cycle = 0;
      final controller = PlaylistDetailController(
        playlistId: 8,
        fetchPlaylistDetail: ({required playlistId}) async {
          cycle += 1;
          if (cycle == 1) {
            return _playlist('Old playlist');
          }
          throw Exception('refresh failed');
        },
      );

      await controller.load();

      await expectLater(controller.refresh(), throwsException);

      expect(controller.playlist?.name, 'Old playlist');
      expect(controller.errorMessage, isNull);
    });
  });
}

PlaylistDto _playlist(String name) {
  return PlaylistDto(
    id: 8,
    name: name,
    kind: 'custom',
    description: '',
    isSystem: false,
    isMutable: true,
    isDeletable: true,
    movieCount: 1,
    createdAt: DateTime.parse('2026-03-12T10:00:00Z'),
    updatedAt: DateTime.parse('2026-03-12T10:00:00Z'),
  );
}
