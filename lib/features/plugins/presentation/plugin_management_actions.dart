import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:oktoast/oktoast.dart';
import 'package:sakuramedia/app/app_platform.dart';
import 'package:sakuramedia/core/network/api_error_message.dart';
import 'package:sakuramedia/features/plugins/data/dto/plugin_dto.dart';
import 'package:sakuramedia/features/plugins/presentation/plugin_zip_picker.dart';
import 'package:sakuramedia/features/plugins/presentation/providers/plugins_provider.dart';
import 'package:sakuramedia/features/shared/presentation/restart_messages.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/feedback/app_confirm_dialog.dart';

/// 插件管理页共用的安装、启停、更新、删除和刷新流程。
///
/// 桌面和移动端各自保留操作入口与布局；此处只集中两端一致的业务反馈。
class PluginManagementActions {
  const PluginManagementActions({required this.context, required this.ref});

  final BuildContext context;
  final WidgetRef ref;

  bool get _isMobile => AppPlatformScope.maybeOf(context) == AppPlatform.mobile;

  AppConfirmVariant get _confirmVariant =>
      _isMobile ? AppConfirmVariant.drawer : AppConfirmVariant.auto;

  Future<void> install() async {
    PluginZipFile? file;
    try {
      file = await pickPluginZip();
    } on PluginZipPickerException catch (error) {
      if (context.mounted) {
        showToast(error.message);
      }
      return;
    }
    if (!context.mounted || file == null) {
      return;
    }

    final confirmed = await showAppConfirmDialog(
      context,
      title: '安装插件',
      message: '将安装「${file.fileName}」。若已存在同名插件，会替换其代码并保留 data/ 运行数据。',
      confirmLabel: '安装',
      dialogKey: const Key('plugins-install-confirm-dialog'),
      confirmKey: const Key('plugins-install-confirm-button'),
      cancelKey: const Key('plugins-install-cancel-button'),
      variant: _confirmVariant,
    );
    if (!confirmed || !context.mounted) {
      return;
    }
    try {
      final refreshed = await ref
          .read(pluginsProvider.notifier)
          .install(fileBytes: file.bytes, fileName: file.fileName);
      if (!context.mounted) {
        return;
      }
      showToast(
        refreshed
            ? buildRestartRequiredMessage('插件已安装')
            : '插件已安装，但列表刷新失败，请稍后重试',
      );
    } catch (error) {
      if (context.mounted) {
        showToast(apiErrorMessage(error, fallback: '安装插件失败'));
      }
    }
  }

  Future<void> toggle(PluginSummaryDto plugin, bool enabled) async {
    try {
      await ref
          .read(pluginsProvider.notifier)
          .setEnabled(plugin.pluginId, enabled);
      if (context.mounted) {
        showToast(buildRestartRequiredMessage(enabled ? '插件已启用' : '插件已停用'));
      }
    } catch (error) {
      if (context.mounted) {
        showToast(apiErrorMessage(error, fallback: '插件启停失败'));
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
      showToast('部分插件的更新检查失败，请稍后重试');
      return;
    }
    final updateCount = ref.read(pluginsProvider).value?.updates.length ?? 0;
    showToast(updateCount == 0 ? '未发现可用更新' : '发现 $updateCount 个插件更新');
  }

  Future<void> upgrade(
    PluginSummaryDto plugin,
    PluginReleaseUpdate update,
  ) async {
    final notes = update.notes.trim();
    final confirmed = await showAppConfirmDialog(
      context,
      title: '更新插件',
      message:
          '将「${plugin.displayName}」从 v${plugin.version} 更新到 v${update.version}。'
          '更新完成后，需手动重启容器才会生效。',
      confirmLabel: '更新',
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
                  '更新内容\n$notes',
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
      failureFallback: '更新插件失败',
    );
    if (confirmed && context.mounted) {
      showToast(buildRestartRequiredMessage('插件已更新'));
    }
  }

  Future<void> remove(PluginSummaryDto plugin) async {
    final confirmed = await showAppConfirmDialog(
      context,
      title: '删除插件',
      message:
          '确认删除「${plugin.displayName}」的插件代码？运行数据（data/）会保留，可在重新安装同一插件后继续使用；仍被媒体库使用的存储插件无法删除。',
      confirmLabel: '删除',
      danger: true,
      dialogKey: const Key('plugins-delete-confirm-dialog'),
      confirmKey: const Key('plugins-delete-confirm-button'),
      cancelKey: const Key('plugins-delete-cancel-button'),
      variant: _confirmVariant,
      onConfirm: () =>
          ref.read(pluginsProvider.notifier).remove(plugin.pluginId),
      failureFallback: '删除插件失败',
    );
    if (confirmed && context.mounted) {
      showToast(buildRestartRequiredMessage('插件已删除'));
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
}
