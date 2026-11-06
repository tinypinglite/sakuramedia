import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/features/playlists/data/dto/playlist_dto.dart';
import 'package:sakuramedia/features/playlists/presentation/providers/playlists_api_provider.dart';
import 'package:sakuramedia/l10n/app_localizations.dart';
import 'package:sakuramedia/widgets/domain/collections/collection_editor_dialog.dart';

enum CreatePlaylistDialogPresentation { dialog, bottomDrawer }

Future<PlaylistDto?> showCreatePlaylistDialog(
  BuildContext context, {
  CreatePlaylistDialogPresentation presentation =
      CreatePlaylistDialogPresentation.dialog,
}) {
  final l10n = AppLocalizations.of(context);
  return showCollectionEditor<PlaylistDto>(
    context,
    config: CollectionEditorConfig<PlaylistDto>(
      presentation: switch (presentation) {
        CreatePlaylistDialogPresentation.dialog =>
          CollectionEditorPresentation.dialog,
        CreatePlaylistDialogPresentation.bottomDrawer =>
          CollectionEditorPresentation.drawer,
      },
      keyPrefix: 'create-playlist',
      copy: CollectionEditorCopy(
        title: l10n.playlistCreateTitle,
        nameHint: l10n.playlistNameHint,
        descriptionHint: l10n.playlistDescriptionHint,
        nameRequiredMessage: l10n.playlistNameRequired,
        submitLabel: l10n.playlistCreateAction,
      ),
      initialName: '',
      initialDescription: '',
      drawerKey: const Key('create-playlist-bottom-sheet'),
      drawerMaxHeightFactor: 0.7,
      errorFallback: (l10n) => l10n.playlistCreateFailed,
      onSubmit: (ref, name, description) {
        return ref
            .read(playlistsApiProvider)
            .createPlaylist(name: name, description: description);
      },
    ),
  );
}
