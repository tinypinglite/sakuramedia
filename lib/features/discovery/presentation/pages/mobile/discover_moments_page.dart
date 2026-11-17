import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/features/discovery/presentation/pages/shared/discovery_recommendation_content.dart';
import 'package:sakuramedia/routes/app_navigation.dart';
import 'package:sakuramedia/theme.dart';

/// 移动推荐时刻壳：移动语义（pageSize 18 / 下拉刷新 /
/// 预览弹层底部抽屉 + drawerKey）收在壳里，实现在 [DiscoveryMomentsContent]。
class MobileDiscoverMomentsPage extends StatelessWidget {
  const MobileDiscoverMomentsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return DiscoveryMomentsContent(
      pageSize: 18,
      keyPrefix: 'mobile-discover-moments',
      headerGap: context.appSpacing.md,
      fallbackPath: mobileOverviewPath,
      previewDrawerKey: const Key(
        'mobile-discover-moments-preview-bottom-sheet',
      ),
      enablePullToRefresh: true,
    );
  }
}
