import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/core/network/api_error_message.dart';
import 'package:sakuramedia/core/network/providers/api_client_provider.dart';
import 'package:sakuramedia/features/plugins/presentation/providers/plugin_bindings_provider.dart';
import 'package:sakuramedia/features/plugins/presentation/providers/plugins_api_provider.dart';
import 'package:sakuramedia/features/plugins/presentation/providers/plugins_provider.dart';
import 'package:sakuramedia/l10n/app_localizations.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/feedback/app_inline_error_banner.dart';
import 'package:sakuramedia/widgets/base/feedback/app_toast.dart';
import 'package:sakuramedia/widgets/base/layout/cards/app_notice_card.dart';
import 'package:sakuramedia/widgets/base/overlays/app_adaptive_modal.dart';
import 'package:sakuramedia/widgets/base/overlays/app_modal_action_row.dart';
import 'package:sakuramedia/widgets/base/overlays/app_modal_dismiss_controller.dart';

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

/// supervisord 会先 `sleep 2` 再重启 api/aps，首次探活要等过这个窗口。
const _initialHealthDelay = Duration(seconds: 3);
const _healthPollInterval = Duration(seconds: 1);
const _maxHealthPollAttempts = 30;
const _requiredConsecutiveHealthy = 2;

/// 插件变更后的重启提示。
///
/// 用户可以选择「稍后」自行处理，或「立即重启」调用
/// `POST /system/plugins/apply` 并等待 api/aps 恢复。重启期间弹窗锁定，
/// 完成或失败后才恢复操作。
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

  final dismissController = AppModalDismissController();
  await showAppAdaptiveModal<void>(
    context: context,
    variant: AppAdaptiveModalVariant.auto,
    modalKey: const Key('plugin-restart-notice-dialog'),
    desktopContentKey: const Key('plugin-restart-notice-dialog-content'),
    desktopWidth: context.appLayoutTokens.dialogWidthSm,
    mobileMaxHeightFactor: 0.55,
    dismissController: dismissController,
    builder: (_) => _PluginRestartNoticeBody(
      title: l10n.pluginRestartNoticeTitle,
      message: message,
      dismissController: dismissController,
    ),
  );
  dismissController.dispose();
}

class _PluginRestartNoticeBody extends ConsumerStatefulWidget {
  const _PluginRestartNoticeBody({
    required this.title,
    required this.message,
    required this.dismissController,
  });

  final String title;
  final String message;
  final AppModalDismissController dismissController;

  @override
  ConsumerState<_PluginRestartNoticeBody> createState() =>
      _PluginRestartNoticeBodyState();
}

class _PluginRestartNoticeBodyState
    extends ConsumerState<_PluginRestartNoticeBody> {
  bool _busy = false;
  String? _errorMessage;

  Future<void> _startRestart() async {
    if (_busy) {
      return;
    }
    final l10n = AppLocalizations.of(context);
    widget.dismissController.setLocked(true);
    setState(() {
      _busy = true;
      _errorMessage = null;
    });

    try {
      final previousBootId = await ref.read(pluginsApiProvider).applyChanges();
      if (!mounted) {
        return;
      }
      final healthy = await _waitForBackend(previousBootId: previousBootId);
      if (!mounted) {
        return;
      }
      if (!healthy) {
        _showFailure(l10n.pluginRestartNoticeWaitTimeout);
        return;
      }
      ref.invalidate(pluginsProvider);
      ref.invalidate(pluginBindingsProvider);
      showToast(l10n.pluginRestartNoticeSuccess, tone: AppToastTone.success);
      Navigator.of(context).pop();
    } catch (error) {
      if (!mounted) {
        return;
      }
      _showFailure(
        apiErrorMessage(
          error,
          fallback: l10n.pluginRestartNoticeApplyFailed,
          l10n: l10n,
        ),
      );
    }
  }

  Future<bool> _waitForBackend({String? previousBootId}) async {
    final client = ref.read(apiClientProvider);
    var sawDown = false;
    var consecutiveHealthy = 0;
    for (var attempt = 0; attempt < _maxHealthPollAttempts; attempt++) {
      await Future<void>.delayed(
        attempt == 0 ? _initialHealthDelay : _healthPollInterval,
      );
      if (!mounted) {
        return false;
      }
      final health = await client.fetchHealth();
      if (!mounted) {
        return false;
      }
      if (!health.healthy) {
        sawDown = true;
        consecutiveHealthy = 0;
        continue;
      }
      // 新后端会返回 boot_id：换进程后再看到 healthy 才算恢复，
      // 不要求一定观察到 down，避免快速重启被误判超时。
      if (previousBootId != null && health.bootId != null) {
        if (health.bootId != previousBootId) {
          return true;
        }
        continue;
      }
      // 旧后端没有 boot_id：沿用「先观察到下线」的保守判断。
      if (!sawDown) {
        continue;
      }
      consecutiveHealthy++;
      if (consecutiveHealthy >= _requiredConsecutiveHealthy) {
        return true;
      }
    }
    return false;
  }

  void _showFailure(String message) {
    if (!mounted) {
      return;
    }
    widget.dismissController.setLocked(false);
    setState(() {
      _busy = false;
      _errorMessage = message;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final spacing = context.appSpacing;
    return Column(
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
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AppNoticeCard(
                  leadingIcon: Icons.restart_alt_rounded,
                  description: widget.message,
                ),
                if (_errorMessage != null) ...[
                  SizedBox(height: spacing.sm),
                  AppInlineErrorBanner(
                    key: const Key('plugin-restart-notice-error'),
                    message: _errorMessage!,
                    tone: AppInlineErrorTone.error,
                  ),
                ],
              ],
            ),
          ),
        ),
        SizedBox(height: spacing.xl),
        if (_busy)
          AppModalActionRow(
            showCancel: false,
            submitKey: const Key('plugin-restart-notice-busy-button'),
            submitLabel: l10n.pluginRestartNoticeBusy,
            isSubmitting: true,
            onSubmit: null,
          )
        else
          AppModalActionRow(
            cancelKey: const Key('plugin-restart-notice-confirm-button'),
            submitKey: const Key('plugin-restart-notice-restart-button'),
            cancelLabel: l10n.pluginRestartNoticeLater,
            submitLabel: _errorMessage == null
                ? l10n.pluginRestartNoticeRestartNow
                : l10n.commonRetry,
            onCancel: () => Navigator.of(context).pop(),
            onSubmit: _startRestart,
          ),
      ],
    );
  }
}
