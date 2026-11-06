import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/features/recent_views/presentation/providers/recent_views_provider.dart';
import 'package:sakuramedia/features/recent_views/presentation/widgets/recent_views_grid_sliver.dart';
import 'package:sakuramedia/routes/app_navigation.dart';
import 'package:sakuramedia/routes/app_routes.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/interaction/refresh/app_page_refresh_scope.dart';

/// 「最近浏览」更多页（桌面）：影片/女优混排的海报卡网格，与「最近添加」
/// 更多页同一套设计。
class DesktopRecentViewsPage extends ConsumerWidget {
  const DesktopRecentViewsPage({super.key});

  Future<void> _refresh(WidgetRef ref) async {
    ref.invalidate(recentViewsProvider);
    try {
      await ref.read(recentViewsProvider.future);
    } catch (_) {
      // 失败由 RecentViewsGridSliver 的 Header/内联错误条单通道呈现。
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AppPageRefreshScope(
      onRefresh: () => _refresh(ref),
      child: CustomScrollView(
        slivers: [
          SliverPadding(
            padding: EdgeInsets.only(top: context.appSpacing.lg),
            sliver: RecentViewsGridSliver(
              onRetry: () => ref.invalidate(recentViewsProvider),
              onMovieTap: (movieNumber) => DesktopRoutes.movieDetail(
                movieNumber: movieNumber,
                fallbackPath: desktopRecentViewsPath,
              ).push(context),
              onActorTap: (actorId) => DesktopRoutes.actorDetail(
                actorId: actorId,
                fallbackPath: desktopRecentViewsPath,
              ).push(context),
            ),
          ),
        ],
      ),
    );
  }
}
