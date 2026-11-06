import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/features/discovery/presentation/pages/shared/discovery_recommendation_content.dart';
import 'package:sakuramedia/routes/app_navigation.dart';
import 'package:sakuramedia/theme.dart';

/// 桌面推荐影片壳：桌面语义（pageSize 24 / 骨架 12 /
/// 顶栏下 lg 间距 / 无下拉刷新）收在壳里，实现在 [DiscoveryMoviesContent]。
class DesktopDiscoverMoviesPage extends StatelessWidget {
  const DesktopDiscoverMoviesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return DiscoveryMoviesContent(
      pageSize: 24,
      keyPrefix: 'desktop-discover-movies',
      headerGap: context.appSpacing.lg,
      placeholderCount: 12,
      basePath: desktopMoviesPath,
    );
  }
}
