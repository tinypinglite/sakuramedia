import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/features/playlists/data/dto/playlist_dto.dart';
import 'package:sakuramedia/features/playlists/presentation/providers/playlists_api_provider.dart';
import 'package:sakuramedia/l10n/app_localizations.dart';
import 'package:sakuramedia/widgets/base/feedback/app_toast.dart';
import 'package:sakuramedia/widgets/domain/collections/collection_editor_dialog.dart';

/// 「编辑播放列表」弹窗形态；与 [showCreatePlaylistDialog] 对齐。
enum EditPlaylistDialogPresentation { dialog, bottomDrawer }

/// 打开「编辑播放列表」弹窗——桌面走 [AppDesktopDialog]、移动走 [showAppBottomDrawer]。
///
/// 提交成功返回后端最新 [PlaylistDto]；取消/关闭返回 `null`。
Future<PlaylistDto?> showEditPlaylistDialog(
  BuildContext context, {
  required PlaylistDto playlist,
  EditPlaylistDialogPresentation presentation =
      EditPlaylistDialogPresentation.dialog,
}) {
  final l10n = AppLocalizations.of(context);
  return showCollectionEditor<PlaylistDto>(
    context,
    config: CollectionEditorConfig<PlaylistDto>(
      presentation: switch (presentation) {
        EditPlaylistDialogPresentation.dialog =>
          CollectionEditorPresentation.dialog,
        EditPlaylistDialogPresentation.bottomDrawer =>
          CollectionEditorPresentation.drawer,
      },
      keyPrefix: 'playlist-edit',
      copy: CollectionEditorCopy(
        title: l10n.playlistEditTitle,
        subtitle: l10n.playlistEditDescription,
        nameHint: l10n.playlistNameHint,
        descriptionHint: l10n.playlistDescriptionHint,
        nameRequiredMessage: l10n.playlistNameRequired,
        submitLabel: l10n.commonSave,
      ),
      initialName: playlist.name,
      initialDescription: playlist.description,
      headerStyle: CollectionEditorHeaderStyle.edit,
      descriptionMaxLines: 3,
      descriptionMinLines: 3,
      autovalidateAfterSubmit: true,
      unfocusOnSubmit: true,
      drawerKey: const Key('playlist-edit-drawer'),
      drawerMaxHeightFactor: 0.62,
      errorFallback: (l10n) => l10n.playlistUpdateFailed,
      onSuccess: (context, result) {
        showToast(
          AppLocalizations.of(context).playlistUpdatedToast,
          tone: AppToastTone.success,
        );
      },
      onSubmit: (ref, name, description) {
        return ref
            .read(playlistsApiProvider)
            .updatePlaylist(
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
