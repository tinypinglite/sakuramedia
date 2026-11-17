import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:sakuramedia/core/network/api_exception.dart';
import 'package:sakuramedia/features/playlists/data/dto/playlist_dto.dart';
import 'package:sakuramedia/features/playlists/presentation/providers/playlists_api_provider.dart';
import 'package:sakuramedia/features/shared/presentation/providers/async_notifier_dispose_guard.dart';
import 'package:sakuramedia/l10n/app_localizations.dart';

part 'playlist_detail_provider.g.dart';

/// 播放列表元信息（详情页头部横幅、总数展示）。
///
/// autoDispose family(playlistId)：每个 detail 页独立实例，离开即释放。
///
/// 迁移前对应：`PlaylistDetailController`。特化错误路径：`404` /
/// `playlist_not_found` 返回「未找到该播放列表」，其余走通用文案。
@Riverpod(retry: kNoAsyncNotifierRetry)
class PlaylistDetail extends _$PlaylistDetail
    with AsyncNotifierDisposeGuardMixin<PlaylistDto> {
  @override
  Future<PlaylistDto> build(int playlistId) async {
    attachDisposeGuard();
    return ref
        .read(playlistsApiProvider)
        .getPlaylistDetail(playlistId: playlistId);
  }

  /// 保留态刷新：不切 loading；失败置 [AsyncError] 由 UI 兜底展示。
  Future<void> refresh() async {
    try {
      final playlist = await ref
          .read(playlistsApiProvider)
          .getPlaylistDetail(playlistId: playlistId);
      if (isDisposed) return;
      state = AsyncData(playlist);
    } catch (error, stack) {
      if (isDisposed) return;
      state = AsyncError(error, stack);
    }
  }

  /// 编辑成功后由详情页就地更新，避免重新请求。
  void applyUpdated(PlaylistDto playlist) {
    if (isDisposed) return;
    state = AsyncData(playlist);
  }
}

/// 把详情加载错误翻译成用户可读文案。保留原 [PlaylistDetailController] 的特化：
/// `404` / `playlist_not_found` → 「未找到该播放列表」；其余通用文案。
String playlistDetailErrorMessage(
  Object error, {
  required AppLocalizations l10n,
}) {
  if (error is ApiException &&
      (error.statusCode == 404 || error.error?.code == 'playlist_not_found')) {
    return l10n.playlistNotFound;
  }
  return l10n.playlistDetailLoadFailed;
}
