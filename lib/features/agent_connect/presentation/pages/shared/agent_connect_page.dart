import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/features/agent_connect/presentation/widgets/agent_connect_card.dart';

/// 「连接 Agent」页：桌面一级入口和移动子页共用，页面标题由顶栏/子页 appbar 提供。
class AgentConnectPage extends StatelessWidget {
  const AgentConnectPage({super.key, required this.isMobile});

  final bool isMobile;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      key: const Key('agent-connect-page'),
      child: AgentConnectCard(isMobile: isMobile),
    );
  }
}
