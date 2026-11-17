import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/features/plugins/presentation/widgets/plugin_market_content.dart';

/// 系统设置「插件」页的「插件市场」分栏：搜索、索引列表与安装 / 更新。
class DesktopPluginMarketSection extends StatelessWidget {
  const DesktopPluginMarketSection({super.key});

  @override
  Widget build(BuildContext context) =>
      const PluginMarketContent(mobile: false);
}
