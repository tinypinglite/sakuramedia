import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/l10n/app_localizations.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/layout/cards/app_notice_card.dart';
import 'package:sakuramedia/widgets/base/overlays/app_adaptive_modal.dart';
import 'package:sakuramedia/widgets/base/overlays/app_modal_action_row.dart';

enum PluginRestartNoticeAction {
  installed,
  upgraded,
  deleted,
  enabled,
  disabled,
  settingsSaved,
  bindingsSaved,
  metadataOrderSaved,
}

/// 插件变更后的重启提示。
///
/// 只负责告知稍后需要重启后端容器，以及重启完成后完全退出并重新打开 App；
/// 弹窗可按标准方式关闭，不强制用户确认。
Future<void> showPluginRestartNoticeDialog(
  BuildContext context, {
  required PluginRestartNoticeAction action,
  String? pluginName,
}) async {
  assert(
    pluginName != null ||
        action == PluginRestartNoticeAction.bindingsSaved ||
        action == PluginRestartNoticeAction.metadataOrderSaved,
    'This restart notice action requires a plugin name.',
  );
  final l10n = AppLocalizations.of(context);
  final message = switch (action) {
    PluginRestartNoticeAction.installed =>
      l10n.pluginRestartNoticeInstalledMessage(pluginName!),
    PluginRestartNoticeAction.upgraded =>
      l10n.pluginRestartNoticeUpgradedMessage(pluginName!),
    PluginRestartNoticeAction.deleted => l10n.pluginRestartNoticeDeletedMessage(
      pluginName!,
    ),
    PluginRestartNoticeAction.enabled => l10n.pluginRestartNoticeEnabledMessage(
      pluginName!,
    ),
    PluginRestartNoticeAction.disabled =>
      l10n.pluginRestartNoticeDisabledMessage(pluginName!),
    PluginRestartNoticeAction.settingsSaved =>
      l10n.pluginRestartNoticeSettingsSavedMessage(pluginName!),
    PluginRestartNoticeAction.bindingsSaved =>
      l10n.pluginRestartNoticeBindingsSavedMessage,
    PluginRestartNoticeAction.metadataOrderSaved =>
      l10n.pluginRestartNoticeMetadataOrderSavedMessage,
  };

  await showAppAdaptiveModal<void>(
    context: context,
    variant: AppAdaptiveModalVariant.auto,
    modalKey: const Key('plugin-restart-notice-dialog'),
    desktopContentKey: const Key('plugin-restart-notice-dialog-content'),
    desktopWidth: context.appLayoutTokens.dialogWidthSm,
    mobileMaxHeightFactor: 0.55,
    builder: (_) => _PluginRestartNoticeBody(
      title: l10n.pluginRestartNoticeTitle,
      message: message,
      confirmLabel: l10n.pluginRestartNoticeConfirm,
    ),
  );
}

class _PluginRestartNoticeBody extends StatelessWidget {
  const _PluginRestartNoticeBody({
    required this.title,
    required this.message,
    required this.confirmLabel,
  });

  final String title;
  final String message;
  final String confirmLabel;

  @override
  Widget build(BuildContext context) {
    final spacing = context.appSpacing;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: resolveAppTextStyle(
            context,
            size: AppTextSize.s18,
            weight: AppTextWeight.semibold,
            tone: AppTextTone.primary,
          ),
        ),
        SizedBox(height: spacing.lg),
        Flexible(
          fit: FlexFit.loose,
          child: SingleChildScrollView(
            child: AppNoticeCard(
              leadingIcon: Icons.restart_alt_rounded,
              description: message,
            ),
          ),
        ),
        SizedBox(height: spacing.xl),
        AppModalActionRow(
          showCancel: false,
          submitKey: const Key('plugin-restart-notice-confirm-button'),
          submitLabel: confirmLabel,
          onSubmit: () => Navigator.of(context).pop(),
        ),
      ],
    );
  }
}
