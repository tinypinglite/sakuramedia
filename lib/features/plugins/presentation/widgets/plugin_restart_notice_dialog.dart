import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/l10n/app_localizations.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/interaction/app_interactive_surface.dart';
import 'package:sakuramedia/widgets/base/layout/cards/app_notice_card.dart';
import 'package:sakuramedia/widgets/base/overlays/app_adaptive_modal.dart';
import 'package:sakuramedia/widgets/base/overlays/app_modal_action_row.dart';

enum PluginRestartNoticeAction { installed, upgraded, deleted }

/// 插件变更后的强制重启提示。
///
/// 遮罩、返回键、桌面关闭按钮和底部抽屉下滑都不能关闭；用户必须勾选
/// 已知晓重启影响，再点确认按钮才会关闭。
Future<void> showPluginRestartNoticeDialog(
  BuildContext context, {
  required PluginRestartNoticeAction action,
  required String pluginName,
}) async {
  final l10n = AppLocalizations.of(context);
  final message = switch (action) {
    PluginRestartNoticeAction.installed =>
      l10n.pluginRestartNoticeInstalledMessage(pluginName),
    PluginRestartNoticeAction.upgraded =>
      l10n.pluginRestartNoticeUpgradedMessage(pluginName),
    PluginRestartNoticeAction.deleted => l10n.pluginRestartNoticeDeletedMessage(
      pluginName,
    ),
  };

  await showAppAdaptiveModal<void>(
    context: context,
    variant: AppAdaptiveModalVariant.auto,
    modalKey: const Key('plugin-restart-notice-dialog'),
    desktopContentKey: const Key('plugin-restart-notice-dialog-content'),
    desktopWidth: context.appLayoutTokens.dialogWidthSm,
    mobileMaxHeightFactor: 0.55,
    barrierDismissible: false,
    enableDrag: false,
    showDrawerHandle: false,
    showDesktopCloseButton: false,
    builder: (_) => _PluginRestartNoticeBody(
      title: l10n.pluginRestartNoticeTitle,
      message: message,
      checkboxLabel: l10n.pluginRestartNoticeCheckbox,
      confirmLabel: l10n.pluginRestartNoticeConfirm,
    ),
  );
}

class _PluginRestartNoticeBody extends StatefulWidget {
  const _PluginRestartNoticeBody({
    required this.title,
    required this.message,
    required this.checkboxLabel,
    required this.confirmLabel,
  });

  final String title;
  final String message;
  final String checkboxLabel;
  final String confirmLabel;

  @override
  State<_PluginRestartNoticeBody> createState() =>
      _PluginRestartNoticeBodyState();
}

class _PluginRestartNoticeBodyState extends State<_PluginRestartNoticeBody> {
  bool _acknowledged = false;

  void _toggleAcknowledged() {
    setState(() => _acknowledged = !_acknowledged);
  }

  @override
  Widget build(BuildContext context) {
    final spacing = context.appSpacing;
    return PopScope(
      canPop: false,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.title,
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
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AppNoticeCard(
                    leadingIcon: Icons.restart_alt_rounded,
                    description: widget.message,
                  ),
                  SizedBox(height: spacing.md),
                  _AcknowledgementCheckbox(
                    label: widget.checkboxLabel,
                    checked: _acknowledged,
                    onToggle: _toggleAcknowledged,
                  ),
                ],
              ),
            ),
          ),
          SizedBox(height: spacing.xl),
          AppModalActionRow(
            showCancel: false,
            submitKey: const Key('plugin-restart-notice-confirm-button'),
            submitLabel: widget.confirmLabel,
            submitDisabled: !_acknowledged,
            onSubmit: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }
}

class _AcknowledgementCheckbox extends StatelessWidget {
  const _AcknowledgementCheckbox({
    required this.label,
    required this.checked,
    required this.onToggle,
  });

  final String label;
  final bool checked;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final spacing = context.appSpacing;
    return Semantics(
      checked: checked,
      label: label,
      onTap: onToggle,
      child: AppInteractiveSurface(
        onTap: onToggle,
        excludeFromSemantics: true,
        focusRingRadius: context.appRadius.smBorder,
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: spacing.md),
          child: ExcludeSemantics(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  checked ? Icons.check_box : Icons.check_box_outline_blank,
                  key: const Key('plugin-restart-notice-checkbox'),
                  size: context.appComponentTokens.iconSizeMd,
                  color: checked
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                SizedBox(width: spacing.sm),
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(top: spacing.xs / 4),
                    child: Text(
                      label,
                      style: resolveAppTextStyle(
                        context,
                        size: AppTextSize.s12,
                        weight: AppTextWeight.regular,
                        tone: AppTextTone.secondary,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
