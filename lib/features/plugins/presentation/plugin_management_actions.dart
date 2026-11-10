import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sakuramedia/widgets/base/feedback/app_toast.dart';
import 'package:sakuramedia/app/app_platform.dart';
import 'package:sakuramedia/app/language/providers/language_providers.dart';
import 'package:sakuramedia/core/network/api_error_message.dart';
import 'package:sakuramedia/core/platform/clipboard_copy.dart';
import 'package:sakuramedia/features/plugins/data/dto/plugin_dto.dart';
import 'package:sakuramedia/features/plugins/data/dto/plugin_market_dto.dart';
import 'package:sakuramedia/features/plugins/presentation/plugin_zip_picker.dart';
import 'package:sakuramedia/features/plugins/presentation/providers/plugin_market_provider.dart';
import 'package:sakuramedia/features/plugins/presentation/providers/plugins_provider.dart';
import 'package:sakuramedia/features/plugins/presentation/widgets/plugin_restart_notice_dialog.dart';
import 'package:sakuramedia/features/shared/presentation/restart_messages.dart';
import 'package:sakuramedia/l10n/app_localizations.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/feedback/app_confirm_dialog.dart';
import 'package:sakuramedia/widgets/base/overlays/app_adaptive_modal.dart';

/// 插件管理页共用的安装、启停、更新、删除和刷新流程。
///
/// 桌面和移动端各自保留操作入口与布局；此处只集中两端一致的业务反馈。
class PluginManagementActions {
  const PluginManagementActions({required this.context, required this.ref});

  final BuildContext context;
  final WidgetRef ref;

  AppLocalizations get _l10n => AppLocalizations.of(context);

  bool get _isMobile => AppPlatformScope.maybeOf(context) == AppPlatform.mobile;

  AppAdaptiveModalVariant get _confirmVariant =>
      _isMobile ? AppAdaptiveModalVariant.drawer : AppAdaptiveModalVariant.auto;

  Future<void> install() async {
    PluginZipFile? file;
    try {
      file = await pickPluginZip(l10n: _l10n);
    } on PluginZipPickerException catch (error) {
      if (context.mounted) {
        showToast(error.message, tone: AppToastTone.error);
      }
      return;
    }
    if (!context.mounted || file == null) {
      return;
    }

    final confirmed = await showAppConfirmDialog(
      context,
      title: _l10n.pluginInstallTitle,
      message: _l10n.pluginInstallMessage(file.fileName),
      confirmLabel: _l10n.pluginInstallConfirm,
      dialogKey: const Key('plugins-install-confirm-dialog'),
      confirmKey: const Key('plugins-install-confirm-button'),
      cancelKey: const Key('plugins-install-cancel-button'),
      variant: _confirmVariant,
    );
    if (!confirmed || !context.mounted) {
      return;
    }
    late final bool refreshed;
    try {
      refreshed = await ref
          .read(pluginsProvider.notifier)
          .install(fileBytes: file.bytes, fileName: file.fileName);
    } catch (error) {
      if (context.mounted) {
        showToast(
          apiErrorMessage(
            error,
            fallback: _l10n.pluginInstallFailed,
            l10n: _l10n,
          ),
          tone: AppToastTone.error,
        );
      }
      return;
    }
    if (!context.mounted) {
      return;
    }
    await showPluginRestartNoticeDialog(
      context,
      action: PluginRestartNoticeAction.installed,
      pluginName: file.fileName,
    );
    if (!refreshed && context.mounted) {
      showToast(_l10n.pluginInstalledRefreshFailed, tone: AppToastTone.error);
    }
  }

  Future<void> toggle(PluginSummaryDto plugin, bool enabled) async {
    try {
      await ref
          .read(pluginsProvider.notifier)
          .setEnabled(plugin.pluginId, enabled);
      if (context.mounted) {
        showToast(
          buildRestartRequiredMessage(
            enabled ? _l10n.pluginEnabled : _l10n.pluginDisabled,
            _l10n,
          ),
          tone: AppToastTone.warning,
        );
      }
    } catch (error) {
      if (context.mounted) {
        showToast(
          apiErrorMessage(
            error,
            fallback: _l10n.pluginToggleFailed,
            l10n: _l10n,
          ),
          tone: AppToastTone.error,
        );
      }
    }
  }

  Future<void> checkUpdates() async {
    final allChecksSucceeded = await ref
        .read(pluginsProvider.notifier)
        .checkUpdates();
    if (!context.mounted) {
      return;
    }
    if (!allChecksSucceeded) {
      showToast(
        _l10n.pluginUpdateCheckPartialFailed,
        tone: AppToastTone.warning,
      );
      return;
    }
    final updateCount = ref.read(pluginsProvider).value?.updates.length ?? 0;
    showToast(
      updateCount == 0
          ? _l10n.pluginNoUpdates
          : _l10n.pluginUpdatesFound(updateCount),
      tone: AppToastTone.info,
    );
  }

  Future<void> upgrade(
    PluginSummaryDto plugin,
    PluginReleaseUpdate update,
  ) async {
    final notes = update.notes.trim();
    final confirmed = await showAppConfirmDialog(
      context,
      title: _l10n.pluginUpgradeTitle,
      message: _l10n.pluginUpgradeMessage(
        plugin.displayName,
        plugin.version,
        update.version,
      ),
      confirmLabel: _l10n.pluginUpgradeConfirm,
      dialogKey: Key('plugin-upgrade-confirm-dialog-${plugin.pluginId}'),
      confirmKey: Key('plugin-upgrade-confirm-button-${plugin.pluginId}'),
      cancelKey: Key('plugin-upgrade-cancel-button-${plugin.pluginId}'),
      extraContent: notes.isEmpty
          ? null
          : ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: _isMobile ? context.appSpacing.xxl * 5 : 180,
              ),
              child: SingleChildScrollView(
                child: Text(
                  _l10n.pluginUpgradeNotes(notes),
                  style: resolveAppTextStyle(
                    context,
                    size: AppTextSize.s12,
                    tone: AppTextTone.secondary,
                  ),
                ),
              ),
            ),
      variant: _confirmVariant,
      onConfirm: () =>
          ref.read(pluginsProvider.notifier).upgrade(plugin.pluginId),
      failureFallback: _l10n.pluginUpgradeFailed,
    );
    if (confirmed && context.mounted) {
      await showPluginRestartNoticeDialog(
        context,
        action: PluginRestartNoticeAction.upgraded,
        pluginName: plugin.displayName,
      );
    }
  }

  Future<void> remove(PluginSummaryDto plugin) async {
    final confirmed = await showAppConfirmDialog(
      context,
      title: _l10n.pluginDeleteTitle,
      message: _l10n.pluginDeleteMessage(plugin.displayName),
      confirmLabel: _l10n.commonDelete,
      danger: true,
      dialogKey: const Key('plugins-delete-confirm-dialog'),
      confirmKey: const Key('plugins-delete-confirm-button'),
      cancelKey: const Key('plugins-delete-cancel-button'),
      variant: _confirmVariant,
      onConfirm: () =>
          ref.read(pluginsProvider.notifier).remove(plugin.pluginId),
      failureFallback: _l10n.pluginDeleteFailed,
    );
    if (confirmed && context.mounted) {
      await showPluginRestartNoticeDialog(
        context,
        action: PluginRestartNoticeAction.deleted,
        pluginName: plugin.displayName,
      );
    }
  }

  Future<void> refresh() async {
    final state = ref.read(pluginsProvider).value;
    if (state?.isInstalling == true ||
        state?.isCheckingUpdates == true ||
        state?.busyPluginIds.isNotEmpty == true) {
      return;
    }
    await ref.read(pluginsProvider.notifier).reload();
  }

  /// 从插件市场下载并安装未安装的插件。
  Future<void> installFromMarket(PluginMarketItemDto plugin) async {
    final release = plugin.latest;
    if (release == null) {
      return;
    }
    final displayName = plugin.localizedDisplayName(
      ref.read(appLanguageControllerProvider),
    );
    final confirmed = await showAppConfirmDialog(
      context,
      title: _l10n.pluginInstallTitle,
      message:
          _l10n.pluginMarketInstallMessage(
            plugin.repo,
            release.version,
            displayName,
          ) +
          (plugin.official ? '' : _l10n.pluginCommunityWarning),
      confirmLabel: _l10n.pluginInstallConfirm,
      dialogKey: Key('plugin-market-install-confirm-dialog-${plugin.pluginId}'),
      confirmKey: Key(
        'plugin-market-install-confirm-button-${plugin.pluginId}',
      ),
      cancelKey: Key('plugin-market-install-cancel-button-${plugin.pluginId}'),
      variant: _confirmVariant,
    );
    if (!confirmed || !context.mounted) {
      return;
    }
    try {
      await ref.read(pluginMarketProvider.notifier).install(plugin);
    } catch (error) {
      if (context.mounted) {
        showToast(
          apiErrorMessage(
            error,
            fallback: _l10n.pluginInstallFailed,
            l10n: _l10n,
          ),
          tone: AppToastTone.error,
        );
      }
      return;
    }
    if (!context.mounted) {
      return;
    }
    await showPluginRestartNoticeDialog(
      context,
      action: PluginRestartNoticeAction.installed,
      pluginName: displayName,
    );
  }

  /// 将已安装插件更新到市场索引里的最新版本。
  Future<void> upgradeFromMarket(
    PluginMarketItemDto plugin,
    String installedVersion,
  ) async {
    final release = plugin.latest;
    if (release == null) {
      return;
    }
    final displayName = plugin.localizedDisplayName(
      ref.read(appLanguageControllerProvider),
    );
    final confirmed = await showAppConfirmDialog(
      context,
      title: _l10n.pluginUpgradeTitle,
      message: _l10n.pluginUpgradeMessage(
        displayName,
        installedVersion,
        release.version,
      ),
      confirmLabel: _l10n.pluginUpgradeConfirm,
      dialogKey: Key('plugin-market-upgrade-confirm-dialog-${plugin.pluginId}'),
      confirmKey: Key(
        'plugin-market-upgrade-confirm-button-${plugin.pluginId}',
      ),
      cancelKey: Key('plugin-market-upgrade-cancel-button-${plugin.pluginId}'),
      variant: _confirmVariant,
    );
    if (!confirmed || !context.mounted) {
      return;
    }
    try {
      await ref.read(pluginMarketProvider.notifier).upgrade(plugin);
    } catch (error) {
      if (context.mounted) {
        showToast(
          apiErrorMessage(
            error,
            fallback: _l10n.pluginUpgradeFailed,
            l10n: _l10n,
          ),
          tone: AppToastTone.error,
        );
      }
      return;
    }
    if (!context.mounted) {
      return;
    }
    await showPluginRestartNoticeDialog(
      context,
      action: PluginRestartNoticeAction.upgraded,
      pluginName: displayName,
    );
  }

  /// 复制市场条目的项目主页地址。
  Future<void> copyHomepageFromMarket(PluginMarketItemDto plugin) async {
    final url = plugin.homepageUrl;
    if (url == null) {
      return;
    }
    final copied = await copyTextToClipboard(url);
    if (context.mounted) {
      showToast(
        copied ? _l10n.pluginHomepageCopied : _l10n.pluginCopyFailed,
        tone: copied ? AppToastTone.success : AppToastTone.error,
      );
    }
  }

  /// 刷新插件市场索引。
  Future<void> refreshMarket() async {
    final state = ref.read(pluginMarketProvider).value;
    if (state != null && state.busyPluginIds.isNotEmpty) {
      return;
    }
    await ref.read(pluginMarketProvider.notifier).reload();
  }
}
