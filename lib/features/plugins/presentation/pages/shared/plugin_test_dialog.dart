import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/features/plugins/data/dto/plugin_dto.dart';
import 'package:sakuramedia/features/plugins/presentation/widgets/plugin_test_content.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/overlays/app_adaptive_modal.dart';

Future<void> showPluginTestDialog(
  BuildContext context, {
  required PluginSummaryDto plugin,
}) {
  return showAppAdaptiveModal<void>(
    context: context,
    dialogKey: const Key('plugin-test-dialog'),
    drawerKey: Key('plugin-test-drawer-${plugin.pluginId}'),
    desktopWidth: context.appLayoutTokens.dialogWidthMd,
    mobileHeightFactor: 0.82,
    builder: (_) => PluginTestContent(plugin: plugin),
  );
}
