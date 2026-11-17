import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sakuramedia/features/subscriptions/presentation/providers/movie_subscription_manager_provider.dart';
import 'package:sakuramedia/features/subscriptions/presentation/widgets/movie_subscription_list_section.dart';
import 'package:sakuramedia/features/subscriptions/presentation/widgets/movie_subscription_status_tabs.dart';
import 'package:sakuramedia/routes/app_navigation.dart';
import 'package:sakuramedia/routes/app_routes.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/interaction/refresh/app_page_refresh_scope.dart';

/// 桌面「订阅管理」页。
///
/// 骨架：状态分段签固定在顶（切签即换数据源），下面是可滚动的列表区。分段签不进
/// 滚动区——它是这一页的导航，滚下去之后还得滚回来才能换签。
///
/// **底色沿用壳层的 `surfaceElevated`（纯白），本页不自铺灰底。** 试过铺
/// `surfacePage`（#F5F5F5）让白卡浮起来——观感上确实分层更清楚，但代价是灰块从顶栏
/// 底下一整片压到底、把分段签也裹进去，跟上方白色顶栏硬切一刀；而且本 app 所有桌面页
/// （媒体管理 / 任务中心）都坐在壳层白底上，单这一页变灰本身就是不协调。
/// 卡片边界交给 [AppLeftCoverCard] 自带的 `borderSubtle` 细边——它本来就是为白底容器
/// 设计的（媒体管理页同款）。
class DesktopMovieSubscriptionsPage extends ConsumerWidget {
  const DesktopMovieSubscriptionsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(movieSubscriptionStatusSelectionProvider);
    final managerProvider = movieSubscriptionManagerProvider(status);
    return AppPageRefreshScope(
      onRefresh: () async => ref.read(managerProvider.notifier).refresh(),
      child: Column(
        key: const Key('desktop-movie-subscriptions-page'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const MovieSubscriptionStatusTabs(),
          SizedBox(height: context.appSpacing.sm),
          Expanded(
            child: MovieSubscriptionListSection(
              key: ValueKey(status),
              onOpenMovie: (context, movieNumber) =>
                  DesktopRoutes.movieDetail(
                    movieNumber: movieNumber,
                    fallbackPath: desktopMovieSubscriptionsPath,
                  ).push(context),
              onOpenDownloads: (context, movieNumber) =>
                  DesktopRoutes.downloadTasks(
                    movieNumber: movieNumber,
                  ).go(context),
            ),
          ),
        ],
      ),
    );
  }
}
