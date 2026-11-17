import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/l10n/app_localizations.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/overlays/app_action_menu.dart';

enum MovieSubscriptionRowAction {
  openDownloads,
  viewFiles,
  retriggerImport,
  searchMagnet,
  deleteDownloads,
  unsubscribe,
}

/// 移动端订阅卡片的「更多」底部操作表。
///
/// 行内不再摆一排无标签图标；这里用 图标 + 中文标签 + 一句说明 让每个动作
/// 自解释，危险动作（删任务 / 取消订阅）用红色文字。不满足条件的项直接隐藏。
/// 标题以番号为主、影片标题为次，让用户先确认"是哪部片"。
Future<MovieSubscriptionRowAction?> showMovieSubscriptionRowActions({
  required BuildContext context,
  required String movieNumber,
  required String movieTitle,
  required bool hasDownloads,
  required bool hasFiles,
  required bool canRetriggerImport,
}) {
  final number = movieNumber.trim();
  final title = movieTitle.trim();
  final primaryTitle = number.isNotEmpty ? number : title;
  final subtitle = title.isNotEmpty && title != primaryTitle ? title : null;
  final l10n = AppLocalizations.of(context);
  return showAppActionMenu<MovieSubscriptionRowAction>(
    context: context,
    presentation: AppMenuPresentation.bottomDrawer,
    drawerKey: const Key('movie-subscription-row-actions'),
    title: primaryTitle,
    titleSubtitle: subtitle,
    items: <AppMenuItem<MovieSubscriptionRowAction>>[
      AppMenuItem(
        key: const Key('movie-subscription-row-action-downloads'),
        value: MovieSubscriptionRowAction.openDownloads,
        label: l10n.subscriptionActionViewDownloads,
        subtitle: l10n.subscriptionActionViewDownloadsSubtitle,
        icon: Icons.download_outlined,
        visible: hasDownloads,
      ),
      AppMenuItem(
        key: const Key('movie-subscription-row-action-files'),
        value: MovieSubscriptionRowAction.viewFiles,
        label: l10n.subscriptionActionViewFiles,
        subtitle: l10n.subscriptionActionViewFilesSubtitle,
        icon: Icons.folder_open_rounded,
        visible: hasFiles,
      ),
      AppMenuItem(
        key: const Key('movie-subscription-row-action-retrigger-import'),
        value: MovieSubscriptionRowAction.retriggerImport,
        label: l10n.subscriptionActionRetriggerImport,
        subtitle: l10n.subscriptionActionRetriggerImportSubtitle,
        icon: Icons.refresh_rounded,
        visible: canRetriggerImport,
      ),
      AppMenuItem(
        key: const Key('movie-subscription-row-action-magnet-search'),
        value: MovieSubscriptionRowAction.searchMagnet,
        label: l10n.subscriptionActionSearchMagnet,
        subtitle: l10n.subscriptionActionSearchMagnetSubtitle,
        icon: Icons.search_rounded,
      ),
      AppMenuItem(
        key: const Key('movie-subscription-row-action-delete-downloads'),
        value: MovieSubscriptionRowAction.deleteDownloads,
        label: l10n.subscriptionActionDeleteDownloads,
        subtitle: l10n.subscriptionActionDeleteDownloadsSubtitle,
        icon: Icons.delete_outline_rounded,
        tone: AppTextTone.error,
        visible: hasDownloads,
      ),
      AppMenuItem(
        key: const Key('movie-subscription-row-action-unsubscribe'),
        value: MovieSubscriptionRowAction.unsubscribe,
        label: l10n.subscriptionActionUnsubscribe,
        subtitle: l10n.subscriptionActionUnsubscribeSubtitle,
        icon: Icons.bookmark_remove_outlined,
        tone: AppTextTone.error,
      ),
    ],
  );
}
