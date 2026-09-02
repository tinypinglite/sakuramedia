import 'package:flutter/material.dart';
import 'package:sakuramedia/features/plugins/data/dto/plugin_dto.dart';
import 'package:sakuramedia/features/plugins/presentation/pages/shared/plugin_settings_content.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/overlays/app_desktop_dialog.dart';

/// 打开单个插件的桌面配置编辑器。
///
/// JSON 配置的读取、校验和保存由 [PluginSettingsContent] 共享；桌面端这里只
/// 提供对话框外壳，移动端则复用同一内容放进底部表单抽屉。
Future<void> showPluginSettingsDialog(
  BuildContext context, {
  required PluginSummaryDto plugin,
}) {
  return showDialog<void>(
    context: context,
    builder: (_) => AppDesktopDialog(
      dialogKey: const Key('plugin-settings-dialog'),
      contentKey: const Key('plugin-settings-dialog-content'),
      width: context.appLayoutTokens.dialogWidthMd,
      child: PluginSettingsContent(plugin: plugin),
    ),
  );
}
