import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/features/plugins/presentation/widgets/plugin_market_content.dart';

/// 移动端插件市场页：搜索、索引卡片列表与安装 / 更新。
class MobilePluginMarketPage extends StatelessWidget {
  const MobilePluginMarketPage({super.key});

  @override
  Widget build(BuildContext context) => const PluginMarketContent(mobile: true);
}
