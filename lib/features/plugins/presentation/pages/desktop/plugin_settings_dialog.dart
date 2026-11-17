import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/features/plugins/data/dto/plugin_dto.dart';
import 'package:sakuramedia/features/plugins/presentation/pages/shared/plugin_settings_content.dart';
import 'package:sakuramedia/features/plugins/presentation/widgets/plugin_restart_notice_dialog.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/overlays/app_adaptive_modal.dart';
import 'package:sakuramedia/widgets/base/overlays/app_modal_dismiss_controller.dart';

/// 打开单个插件的桌面配置编辑器。
///
/// JSON 配置的读取、校验和保存由 [PluginSettingsContent] 共享；桌面端这里只
/// 提供对话框外壳，移动端则复用同一内容放进底部表单抽屉。
Future<void> showPluginSettingsDialog(
  BuildContext context, {
  required PluginSummaryDto plugin,
}) async {
  final dismissController = AppModalDismissController();
  final saved = await showAppAdaptiveModal<bool>(
    context: context,
    variant: AppAdaptiveModalVariant.dialog,
    dialogKey: const Key('plugin-settings-dialog'),
    desktopContentKey: const Key('plugin-settings-dialog-content'),
    desktopWidth: context.appLayoutTokens.dialogWidthMd,
    dismissController: dismissController,
    builder: (_) => PluginSettingsContent(
      plugin: plugin,
      dismissController: dismissController,
    ),
  );
  if (saved == true && context.mounted) {
    await showPluginRestartNoticeDialog(
      context,
      action: PluginRestartNoticeAction.settingsSaved,
      pluginName: plugin.displayName,
    );
  }
}
