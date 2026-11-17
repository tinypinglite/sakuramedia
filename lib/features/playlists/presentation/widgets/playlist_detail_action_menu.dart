import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/features/playlists/data/dto/playlist_dto.dart';
import 'package:sakuramedia/l10n/app_localizations.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/overlays/app_action_menu.dart';

enum PlaylistDetailActionType { edit, delete }

/// 播放列表详情横幅「···」菜单：编辑信息 / 删除播放列表。
///
/// 入口为横幅右上角常显按钮——桌面用锚定按钮的 [AppMenuPresentation.popup]，
/// 移动端用 [AppMenuPresentation.bottomDrawer]（底部操作表）。
Future<PlaylistDetailActionType?> showPlaylistDetailActionMenu({
  required BuildContext context,
  required PlaylistDto playlist,
  AppMenuPresentation presentation = AppMenuPresentation.popup,
  Offset position = Offset.zero,
}) {
  final isDrawer = presentation == AppMenuPresentation.bottomDrawer;
  final l10n = AppLocalizations.of(context);
  return showAppActionMenu<PlaylistDetailActionType>(
    context: context,
    globalPosition: position,
    presentation: presentation,
    drawerKey: const Key('playlist-detail-actions-drawer'),
    title: isDrawer ? l10n.playlistActionsTooltip : null,
    items: <AppMenuItem<PlaylistDetailActionType>>[
      if (playlist.isMutable)
        AppMenuItem(
          key: const Key('playlist-detail-action-edit'),
          value: PlaylistDetailActionType.edit,
          label: l10n.playlistEditInfo,
          icon: Icons.edit_outlined,
        ),
      if (playlist.isDeletable)
        AppMenuItem(
          key: const Key('playlist-detail-action-delete'),
          value: PlaylistDetailActionType.delete,
          label: l10n.playlistDeleteTitle,
          icon: Icons.delete_outline_rounded,
          tone: AppTextTone.error,
        ),
    ],
  );
}
