import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:sakuramedia/features/playlists/data/dto/playlist_dto.dart';
import 'package:sakuramedia/features/playlists/presentation/providers/playlists_api_provider.dart';

part 'system_playlist_provider.g.dart';

/// 按 `kind` 查找系统播放列表（收藏 / 最近播放）。
///
/// 后端在首次产生播放记录时才创建「最近播放」，收藏由初始化流程预置，
/// 因此列表不存在时返回 null，由页面展示空态。
@riverpod
Future<PlaylistDto?> systemPlaylist(Ref ref, String kind) async {
  final playlists = await ref
      .watch(playlistsApiProvider)
      .getPlaylists(includeSystem: true);
  for (final playlist in playlists) {
    if (playlist.kind == kind) {
      return playlist;
    }
  }
  return null;
}
