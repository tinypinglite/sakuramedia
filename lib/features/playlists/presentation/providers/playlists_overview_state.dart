import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sakuramedia/features/playlists/data/dto/playlist_dto.dart';

typedef PlaylistsOverviewView = ({
  List<PlaylistDto> playlists,
  bool isLoading,
  Object? error,
});

PlaylistsOverviewView selectPlaylistsOverview(
  AsyncValue<PlaylistsOverviewState> async,
) {
  final state = async.value;
  return (
    playlists: state?.playlists ?? const <PlaylistDto>[],
    isLoading: async.isLoading && state == null,
    error: async.hasError && state == null ? async.error : null,
  );
}

/// 播放列表概览 State：全量已加载列表（应用了持久化顺序）+ 各列表首图缓存。
///
/// [coverUrls] 逐个后台 fetch，key = playlistId，value = null 表示尚未拉到 /
/// 拉取失败 / 空列表——UI 都当"无封面"处理。
@immutable
class PlaylistsOverviewState {
  const PlaylistsOverviewState({
    this.playlists = const <PlaylistDto>[],
    this.coverUrls = const <int, String?>{},
  });

  final List<PlaylistDto> playlists;
  final Map<int, String?> coverUrls;

  bool get isEmpty => playlists.isEmpty;

  String? coverUrlFor(int playlistId) => coverUrls[playlistId];

  PlaylistsOverviewState copyWith({
    List<PlaylistDto>? playlists,
    Map<int, String?>? coverUrls,
  }) {
    return PlaylistsOverviewState(
      playlists: playlists ?? this.playlists,
      coverUrls: coverUrls ?? this.coverUrls,
    );
  }
}
