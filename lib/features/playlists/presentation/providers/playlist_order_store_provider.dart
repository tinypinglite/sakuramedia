import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:sakuramedia/features/playlists/data/playlist_order_store.dart';

part 'playlist_order_store_provider.g.dart';

/// 播放列表顺序的持久化桥（SharedPreferences 实现）。
///
/// 测试用 `overrideWithValue(InMemoryPlaylistOrderStore())` 替换。
@Riverpod(keepAlive: true)
PlaylistOrderStore playlistOrderStore(Ref ref) =>
    const SharedPreferencesPlaylistOrderStore();
