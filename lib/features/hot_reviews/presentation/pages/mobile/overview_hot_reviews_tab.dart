import 'package:flutter/widgets.dart';
import 'package:sakuramedia/features/hot_reviews/presentation/pages/shared/hot_reviews_content.dart';
import 'package:sakuramedia/routes/app_navigation_actions.dart';

/// 移动概览「热评」tab 壳：移动语义（单列网格 / 下拉刷新 / 底部抽屉筛选 /
/// push 移动影片详情）收在壳里，全部实现在共享的 [HotReviewsContent]。
class MobileOverviewHotReviewsTab extends StatelessWidget {
  const MobileOverviewHotReviewsTab({super.key});

  @override
  Widget build(BuildContext context) {
    return KeyedSubtree(
      key: const Key('mobile-overview-hot-reviews-tab'),
      child: HotReviewsContent(
        minColumns: 1,
        maxColumns: 2,
        targetCardWidth: 360,
        enablePullToRefresh: true,
        useMobileFilterDrawer: true,
        scrollPhysics: const AlwaysScrollableScrollPhysics(),
        onOpenMovieDetail: (context, item) {
          final movieNumber = item.movie.movieNumber.trim();
          if (movieNumber.isEmpty) {
            return;
          }
          context.pushMobileMovieDetail(movieNumber: movieNumber);
        },
      ),
    );
  }
}
