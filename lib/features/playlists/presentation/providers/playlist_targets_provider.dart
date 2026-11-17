import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:sakuramedia/features/playlists/data/dto/playlist_dto.dart';
import 'package:sakuramedia/features/playlists/presentation/providers/playlists_api_provider.dart';

part 'playlist_targets_provider.g.dart';

/// 影片批量「加入播放列表」可选的目标：自定义列表和系统收藏。
///
/// 最近播放由播放行为自动维护，不能作为手动加入目标。
@riverpod
Future<List<PlaylistDto>> playlistTargets(Ref ref) async {
  final playlists = await ref.watch(playlistsApiProvider).getPlaylists();
  return playlists
      .where(
        (playlist) =>
            playlist.kind == PlaylistKind.custom ||
            playlist.kind == PlaylistKind.favorites,
      )
      .toList(growable: false);
}
