import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/l10n/app_localizations.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/overlays/app_action_menu.dart';

enum MediaManagementRowAction { editTags, retryThumbnails, transfer, delete }

/// 移动端媒体卡片的「更多」底部操作表。
///
/// 行内不再摆一排无标签图标；这里用 图标 + 中文标签 + 一句说明 让每个动作
/// 自解释，危险动作（删除）用红色文字。不满足条件的项直接隐藏。
/// 标题以番号为主、影片标题为次，让用户先确认"是哪条媒体"。
Future<MediaManagementRowAction?> showMediaManagementRowActions({
  required BuildContext context,
  required String title,
  String? titleSubtitle,
  required String? retryThumbnailsLabel,
  String? retryThumbnailsSubtitle,
  bool showEditTags = false,
}) {
  final l10n = AppLocalizations.of(context);
  return showAppActionMenu<MediaManagementRowAction>(
    context: context,
    presentation: AppMenuPresentation.bottomDrawer,
    drawerKey: const Key('media-management-row-actions'),
    title: title,
    titleSubtitle: titleSubtitle,
    items: <AppMenuItem<MediaManagementRowAction>>[
      AppMenuItem(
        key: const Key('media-management-row-action-edit-tags'),
        value: MediaManagementRowAction.editTags,
        label: l10n.mediaListTagsEdit,
        icon: Icons.sell_outlined,
        visible: showEditTags,
      ),
      AppMenuItem(
        key: const Key('media-management-row-action-retry-thumbnails'),
        value: MediaManagementRowAction.retryThumbnails,
        label: retryThumbnailsLabel ?? '',
        subtitle: retryThumbnailsSubtitle,
        icon: Icons.refresh_rounded,
        visible: retryThumbnailsLabel != null,
      ),
      AppMenuItem(
        key: const Key('media-management-row-action-transfer'),
        value: MediaManagementRowAction.transfer,
        label: l10n.mediaListActionTransfer,
        subtitle: l10n.mediaListActionTransferToLibrary,
        icon: Icons.drive_file_move_outline,
      ),
      AppMenuItem(
        key: const Key('media-management-row-action-delete'),
        value: MediaManagementRowAction.delete,
        label: l10n.mediaListRowActionDelete,
        subtitle: l10n.mediaListRowActionDeleteSubtitle,
        icon: Icons.delete_outline_rounded,
        tone: AppTextTone.error,
      ),
    ],
  );
}
