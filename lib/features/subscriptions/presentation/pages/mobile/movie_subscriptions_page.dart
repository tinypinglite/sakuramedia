import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sakuramedia/features/subscriptions/presentation/providers/movie_subscription_manager_provider.dart';
import 'package:sakuramedia/features/subscriptions/presentation/widgets/movie_subscription_list_section.dart';
import 'package:sakuramedia/features/subscriptions/presentation/widgets/movie_subscription_status_tabs.dart';
import 'package:sakuramedia/routes/app_routes.dart';
import 'package:sakuramedia/theme.dart';

/// 移动端「订阅管理」页：状态分段签固定在顶，下面是双端分流的列表主体
/// （底部抽屉筛选 + 贴底批量操作条）。
class MobileMovieSubscriptionsPage extends ConsumerWidget {
  const MobileMovieSubscriptionsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(movieSubscriptionStatusSelectionProvider);
    return Column(
      key: const Key('mobile-movie-subscriptions-page'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const MovieSubscriptionStatusTabs(),
        SizedBox(height: context.appSpacing.sm),
        Expanded(
          child: MovieSubscriptionListSection(
            key: ValueKey(status),
            mobile: true,
            onOpenMovie: (context, movieNumber) => MobileRoutes.movieDetail(
              movieNumber: movieNumber,
            ).push(context),
            onOpenDownloads: (context, movieNumber) =>
                MobileRoutes.downloadTasks(
                  movieNumber: movieNumber,
                ).go(context),
          ),
        ),
      ],
    );
  }
}
