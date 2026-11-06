import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/features/discovery/presentation/pages/shared/discovery_recommendation_content.dart';
import 'package:sakuramedia/routes/app_navigation.dart';
import 'package:sakuramedia/theme.dart';

/// 桌面推荐时刻壳：桌面语义（pageSize 24 / 无下拉刷新 /
/// 预览弹层落对话框、无 drawerKey）收在壳里，实现在 [DiscoveryMomentsContent]。
class DesktopDiscoverMomentsPage extends StatelessWidget {
  const DesktopDiscoverMomentsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return DiscoveryMomentsContent(
      pageSize: 24,
      keyPrefix: 'desktop-discover-moments',
      headerGap: context.appSpacing.lg,
      fallbackPath: desktopDiscoverMomentsPath,
    );
  }
}
