import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/features/discovery/presentation/pages/shared/discovery_recommendation_content.dart';
import 'package:sakuramedia/routes/app_navigation.dart';
import 'package:sakuramedia/theme.dart';

/// 移动推荐影片壳：移动语义（pageSize 18 / 骨架 6 /
/// 顶栏下 md 间距 / 下拉刷新）收在壳里，实现在 [DiscoveryMoviesContent]。
class MobileDiscoverMoviesPage extends StatelessWidget {
  const MobileDiscoverMoviesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return DiscoveryMoviesContent(
      pageSize: 18,
      keyPrefix: 'mobile-discover-movies',
      headerGap: context.appSpacing.md,
      placeholderCount: 6,
      basePath: mobileMoviesPath,
      enablePullToRefresh: true,
    );
  }
}
