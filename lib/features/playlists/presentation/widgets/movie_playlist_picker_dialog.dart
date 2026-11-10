import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/features/movies/data/dto/detail/movie_detail_dto.dart';
import 'package:sakuramedia/features/playlists/data/dto/playlist_dto.dart';
import 'package:sakuramedia/features/playlists/presentation/providers/playlists_api_provider.dart';
import 'package:sakuramedia/features/playlists/presentation/widgets/playlist_editor_dialog.dart';
import 'package:sakuramedia/l10n/app_localizations.dart';
import 'package:sakuramedia/widgets/base/overlays/app_adaptive_modal.dart';
import 'package:sakuramedia/widgets/domain/collections/collection_editor_dialog.dart';
import 'package:sakuramedia/widgets/domain/collections/collection_membership_dialog.dart';

Future<void> showMoviePlaylistPickerDialog(
  BuildContext context, {
  required String movieNumber,
  required List<MoviePlaylistSummaryDto> initialPlaylists,
  AppAdaptiveModalVariant presentation = AppAdaptiveModalVariant.dialog,
}) {
  final l10n = AppLocalizations.of(context);
  return showCollectionMembershipDialog<PlaylistDto>(
    context: context,
    variant: presentation,
    config: CollectionMembershipConfig<PlaylistDto>(
      keyPrefix: 'movie-playlist',
      searchHint: l10n.playlistSearchHint,
      createLabel: l10n.playlistCreateTitle,
      emptyMessage: l10n.playlistEmpty,
      noMatchMessage: l10n.playlistNoMatch,
      loadErrorFallback: l10n.playlistPickerLoadFailed,
      addErrorFallback: l10n.playlistAddFailed,
      removeErrorFallback: l10n.playlistRemoveFailed,
      loadCollections: (ref) async {
        final playlists = await ref.read(playlistsApiProvider).getPlaylists();
        return playlists
            .where(
              (playlist) =>
                  !playlist.isSystem || playlist.kind == PlaylistKind.favorites,
            )
            .toList(growable: false);
      },
      loadSelectedIds: (ref) async =>
          initialPlaylists.map((playlist) => playlist.id).toSet(),
      add: (ref, playlistId) => ref
          .read(playlistsApiProvider)
          .addMovieToPlaylist(playlistId: playlistId, movieNumber: movieNumber),
      remove: (ref, playlistId) => ref
          .read(playlistsApiProvider)
          .removeMovieFromPlaylist(
            playlistId: playlistId,
            movieNumber: movieNumber,
          ),
      createCollection: (context, ref) => showPlaylistEditor(
        context,
        presentation: AppAdaptiveModalShellScope.maybeIsDrawer(context)
            ? CollectionEditorPresentation.drawer
            : CollectionEditorPresentation.dialog,
      ),
      idOf: (playlist) => playlist.id,
      nameOf: (playlist) => playlist.name,
      trailingTextOf: (playlist) =>
          l10n.playlistMovieCountShort(playlist.movieCount),
      blockWhileUpdating: false,
      dialogKey: const Key('movie-playlist-picker-dialog'),
      drawerKey: const Key('movie-playlist-picker-bottom-sheet'),
    ),
  );
}
