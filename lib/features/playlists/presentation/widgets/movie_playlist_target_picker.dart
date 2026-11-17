import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/features/playlists/data/dto/playlist_dto.dart';
import 'package:sakuramedia/features/playlists/presentation/providers/playlist_targets_provider.dart';
import 'package:sakuramedia/features/playlists/presentation/widgets/playlist_editor_dialog.dart';
import 'package:sakuramedia/l10n/app_localizations.dart';
import 'package:sakuramedia/widgets/base/overlays/app_adaptive_modal.dart';
import 'package:sakuramedia/widgets/domain/collections/collection_editor_dialog.dart';
import 'package:sakuramedia/widgets/domain/collections/collection_target_picker.dart';

/// 为多选影片选择一个目标播放列表；取消返回 `null`，实际批量写入由调用方执行。
Future<PlaylistDto?> showMoviePlaylistTargetPicker(
  BuildContext context, {
  AppAdaptiveModalVariant presentation = AppAdaptiveModalVariant.auto,
  int? excludedPlaylistId,
}) {
  final l10n = AppLocalizations.of(context);
  return showCollectionTargetPicker<PlaylistDto>(
    context: context,
    variant: presentation,
    drawerKey: const Key('movie-playlist-target-picker-bottom-sheet'),
    optionKeyPrefix: 'movie-playlist-target-picker-option-',
    watchCollections: (ref) => ref.watch(playlistTargetsProvider),
    idOf: (playlist) => playlist.id,
    nameOf: (playlist) => playlist.name,
    countTextOf: (playlist) =>
        l10n.playlistMovieCountShort(playlist.movieCount),
    excludedCollectionId: excludedPlaylistId,
    searchHint: l10n.moviePlaylistTargetSearchHint,
    emptyMessage: l10n.moviePlaylistTargetEmpty,
    noMatchMessage: l10n.moviePlaylistTargetNoMatch,
    createAndAddLabel: l10n.moviePlaylistTargetCreateAndAdd,
    onCreate: (context, isDrawer) => showPlaylistEditor(
      context,
      presentation: isDrawer
          ? CollectionEditorPresentation.drawer
          : CollectionEditorPresentation.dialog,
    ),
  );
}
