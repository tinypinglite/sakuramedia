import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/features/playlists/data/dto/playlist_dto.dart';
import 'package:sakuramedia/features/playlists/presentation/providers/playlists_api_provider.dart';
import 'package:sakuramedia/l10n/app_localizations.dart';
import 'package:sakuramedia/widgets/base/feedback/app_toast.dart';
import 'package:sakuramedia/widgets/domain/collections/collection_editor_dialog.dart';

/// 新建或编辑播放列表；[playlist] 为空表示新建。
Future<PlaylistDto?> showPlaylistEditor(
  BuildContext context, {
  PlaylistDto? playlist,
  CollectionEditorPresentation presentation =
      CollectionEditorPresentation.dialog,
}) {
  final l10n = AppLocalizations.of(context);
  final isEditing = playlist != null;
  return showCollectionEditor<PlaylistDto>(
    context,
    config: CollectionEditorConfig<PlaylistDto>(
      presentation: presentation,
      keyPrefix: isEditing ? 'playlist-edit' : 'create-playlist',
      copy: CollectionEditorCopy(
        title: isEditing ? l10n.playlistEditTitle : l10n.playlistCreateTitle,
        subtitle: isEditing ? l10n.playlistEditDescription : null,
        nameHint: l10n.playlistNameHint,
        descriptionHint: l10n.playlistDescriptionHint,
        nameRequiredMessage: l10n.playlistNameRequired,
        submitLabel: isEditing ? l10n.commonSave : l10n.playlistCreateAction,
      ),
      initialName: playlist?.name ?? '',
      initialDescription: playlist?.description ?? '',
      headerStyle: isEditing
          ? CollectionEditorHeaderStyle.edit
          : CollectionEditorHeaderStyle.plain,
      descriptionMaxLines: isEditing ? 3 : 1,
      descriptionMinLines: isEditing ? 3 : 1,
      autovalidateAfterSubmit: isEditing,
      unfocusOnSubmit: isEditing,
      drawerKey: Key(
        isEditing ? 'playlist-edit-drawer' : 'create-playlist-bottom-sheet',
      ),
      drawerMaxHeightFactor: isEditing ? 0.62 : 0.7,
      errorFallback: (l10n) =>
          isEditing ? l10n.playlistUpdateFailed : l10n.playlistCreateFailed,
      onSuccess: isEditing
          ? (context, result) => showToast(
              AppLocalizations.of(context).playlistUpdatedToast,
              tone: AppToastTone.success,
            )
          : null,
      onSubmit: (ref, name, description) {
        final api = ref.read(playlistsApiProvider);
        if (!isEditing) {
          return api.createPlaylist(name: name, description: description);
        }
        return api.updatePlaylist(
          playlistId: playlist.id,
          payload: UpdatePlaylistPayload(
            name: name.trim(),
            description: description.trim(),
          ),
        );
      },
    ),
  );
}
