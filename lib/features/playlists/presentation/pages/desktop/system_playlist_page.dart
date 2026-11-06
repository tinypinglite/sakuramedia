import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/core/network/api_error_message.dart';
import 'package:sakuramedia/features/playlists/data/dto/playlist_dto.dart';
import 'package:sakuramedia/features/playlists/presentation/pages/desktop/playlist_detail_page.dart';
import 'package:sakuramedia/features/playlists/presentation/pages/shared/playlist_detail_content.dart';
import 'package:sakuramedia/features/playlists/presentation/providers/system_playlist_provider.dart';
import 'package:sakuramedia/l10n/app_localizations.dart';
import 'package:sakuramedia/widgets/base/feedback/app_empty_state.dart';

/// 系统播放列表（收藏 / 最近播放）的桌面入口页。
///
/// 只负责按 kind 解析播放列表 ID，真正的列表 UI 复用播放列表详情页。
class DesktopSystemPlaylistPage extends ConsumerWidget {
  const DesktopSystemPlaylistPage({
    super.key,
    required this.kind,
    required this.fallbackPath,
  });

  final String kind;

  /// 从影片详情返回时的落点。
  final String fallbackPath;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(systemPlaylistProvider(kind));
    final playlist = async.value;

    if (async.isLoading && playlist == null) {
      return const PlaylistDetailLoadingContent();
    }

    if (playlist == null) {
      final l10n = AppLocalizations.of(context);
      return AppEmptyState(
        icon: _emptyIcon,
        message: async.hasError
            ? apiErrorMessage(
                async.error!,
                fallback: l10n.playlistLoadFailed,
                l10n: l10n,
              )
            : kind == PlaylistKind.favorites
            ? l10n.playlistFavoritesNotReady
            : l10n.playlistNoWatchHistory,
        onRetry: async.hasError
            ? () => ref.invalidate(systemPlaylistProvider(kind))
            : null,
      );
    }

    return DesktopPlaylistDetailPage(
      playlistId: playlist.id,
      movieFallbackPath: fallbackPath,
    );
  }

  IconData get _emptyIcon => kind == PlaylistKind.favorites
      ? Icons.favorite_border_rounded
      : Icons.play_circle_outline_rounded;
}
