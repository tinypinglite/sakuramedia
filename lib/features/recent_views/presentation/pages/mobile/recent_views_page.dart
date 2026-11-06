import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/features/recent_views/presentation/providers/recent_views_provider.dart';
import 'package:sakuramedia/features/recent_views/presentation/widgets/recent_views_grid_sliver.dart';
import 'package:sakuramedia/routes/app_routes.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/layout/scrolling/app_adaptive_refresh_scroll_view.dart';

/// 「最近浏览」更多页（移动）：影片/女优混排的海报卡网格，与「最近添加」
/// 更多页同一套设计。
class MobileRecentViewsPage extends ConsumerWidget {
  const MobileRecentViewsPage({super.key});

  Future<void> _refresh(WidgetRef ref) async {
    ref.invalidate(recentViewsProvider);
    try {
      await ref.read(recentViewsProvider.future);
    } catch (_) {
      // 失败由 RecentViewsGridSliver 的内联错误条单通道呈现。
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AppAdaptiveRefreshScrollView(
      onRefresh: () => _refresh(ref),
      slivers: [
        SliverPadding(
          padding: EdgeInsets.symmetric(vertical: context.appSpacing.md),
          sliver: RecentViewsGridSliver(
            onRetry: () => ref.invalidate(recentViewsProvider),
            onMovieTap: (movieNumber) => MobileRoutes.movieDetail(
              movieNumber: movieNumber,
            ).push(context),
            onActorTap: (actorId) =>
                MobileRoutes.actorDetail(actorId: actorId).push(context),
          ),
        ),
      ],
    );
  }
}
