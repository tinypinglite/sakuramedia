import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/features/movies/presentation/pages/tv/tv_movie_summary_grid_page.dart';
import 'package:sakuramedia/features/movies/presentation/providers/movie_summary_scope.dart';
import 'package:sakuramedia/features/playlists/presentation/controllers/playlist_filter_state.dart';
import 'package:sakuramedia/features/playlists/presentation/providers/playlist_detail_provider.dart';
import 'package:sakuramedia/l10n/app_localizations.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/feedback/app_error_state.dart';
import 'package:sakuramedia/widgets/base/tv/tv_page.dart';

/// 电视端播放列表详情。
///
/// 智能列表的成员条件保存在 `smart_filter` 里，电影端点不会替客户端兜底；
/// 必须等详情返回后把保存的筛选和标签预填进 [MovieSummaryScope.playlist]，
/// 否则首拉会带空覆盖参数，看到的是未按保存条件筛选的结果。
class TvPlaylistDetailPage extends ConsumerWidget {
  const TvPlaylistDetailPage({
    super.key,
    required this.playlistId,
    this.playlistName,
  });

  final int playlistId;
  final String? playlistName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final async = ref.watch(playlistDetailProvider(playlistId));
    final playlist = async.value;
    final routeName = playlistName?.trim() ?? '';
    final loadedName = playlist?.name.trim() ?? '';
    final title = loadedName.isNotEmpty
        ? loadedName
        : routeName.isNotEmpty
        ? routeName
        : l10n.routePlaylistDetailsTitle;

    if (playlist == null) {
      return TvPagePadding(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TvPageHeader(title: title),
            SizedBox(height: context.appSpacing.xl),
            Expanded(
              child: async.hasError
                  ? AppErrorState(
                      title: l10n.baseActionFailed,
                      message: playlistDetailErrorMessage(
                        async.error!,
                        l10n: l10n,
                      ),
                      onRetry: () =>
                          ref.invalidate(playlistDetailProvider(playlistId)),
                    )
                  : const Center(child: CircularProgressIndicator()),
            ),
          ],
        ),
      );
    }

    final smartFilter = playlist.smartFilter;
    final savedFilter = PlaylistFilterState.fromSmartFilter(smartFilter);
    final savedTagMatch = TagMatchModeX.fromApiValue(
      smartFilter?.tagMatch ?? 'or',
    );
    return TvMovieSummaryGridPage(
      scope: MovieSummaryScope.playlist(
        playlistId: playlistId,
        pageSize: 36,
        initialPlaylistFilter: smartFilter == null ? null : savedFilter,
        initialTagIds: smartFilter?.tagIds ?? const <int>[],
        initialTagMatch: savedTagMatch,
      ),
      title: title,
      playlistDefaultSortLabel: playlistSortLabel(smartFilter?.sort, l10n),
      pageKey: const Key('tv-playlist-detail-page'),
    );
  }
}
