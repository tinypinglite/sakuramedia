import 'package:flutter/material.dart';
import 'package:sakuramedia/features/hot_reviews/presentation/pages/shared/hot_reviews_content.dart';

export 'package:sakuramedia/features/hot_reviews/presentation/pages/shared/hot_reviews_content.dart'
    show HotReviewMovieOpenHandler;

/// 桌面热评壳：7 个配置参数（列数 / 刷新 / 抽屉 / 导航）默认桌面语义，
/// 全部实现在共享的 [HotReviewsContent]。
class DesktopHotReviewsPage extends StatelessWidget {
  const DesktopHotReviewsPage({
    super.key,
    this.onOpenMovieDetail,
    this.minColumns = 2,
    this.maxColumns = 4,
    this.targetCardWidth = 420,
    this.enablePullToRefresh = false,
    this.scrollPhysics,
    this.useMobileFilterDrawer = false,
  }) : assert(minColumns >= 1),
       assert(maxColumns >= minColumns),
       assert(targetCardWidth > 0);

  final HotReviewMovieOpenHandler? onOpenMovieDetail;
  final int minColumns;
  final int maxColumns;
  final double targetCardWidth;
  final bool enablePullToRefresh;
  final ScrollPhysics? scrollPhysics;
  final bool useMobileFilterDrawer;

  @override
  Widget build(BuildContext context) {
    return HotReviewsContent(
      onOpenMovieDetail: onOpenMovieDetail,
      minColumns: minColumns,
      maxColumns: maxColumns,
      targetCardWidth: targetCardWidth,
      enablePullToRefresh: enablePullToRefresh,
      scrollPhysics: scrollPhysics,
      useMobileFilterDrawer: useMobileFilterDrawer,
    );
  }
}
