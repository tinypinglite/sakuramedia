import 'package:flutter/material.dart';
import 'package:oktoast/oktoast.dart';
import 'package:sakuramedia/features/movies/presentation/pages/shared/movie_summary_list_content.dart';
import 'package:sakuramedia/features/movies/presentation/providers/movie_summary_scope.dart';
import 'package:sakuramedia/routes/mobile_routes.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/layout/scrolling/app_adaptive_refresh_scroll_view.dart';
import 'package:sakuramedia/widgets/base/navigation/app_list_header.dart';

class MobileFollowPage extends StatelessWidget {
  const MobileFollowPage({super.key});

  static const _scope = MovieSummaryScope.subscribedActorsLatest(
    pageSize: 18,
    initialLoadErrorText: '女优上新加载失败，请稍后重试',
  );

  @override
  Widget build(BuildContext context) {
    return MovieSummaryListContent(
      scope: _scope,
      surfaceColor: context.appColors.surfaceCard,
      contentKey: const Key('mobile-follow-page'),
      totalKey: const Key('mobile-follow-page-total'),
      sectionSpacing: context.appSpacing.md,
      emptyMessage: '暂无女优上新，先订阅感兴趣的女优，等定时任务同步后展示',
      onMovieTap: (context, movieNumber) =>
          MobileMovieDetailRouteData(movieNumber: movieNumber).push(context),
      headerBuilder: (context, args) => AppListHeader(
        informationSlots: <AppListHeaderInfo>[
          AppListHeaderInfo(
            key: const Key('mobile-follow-page-total'),
            label: '${args.total} 部',
          ),
        ],
      ),
      useMobileSelectionLayout: true,
      bodyBuilder: (context, scrollController, sliver, onRefresh) =>
          AppAdaptiveRefreshScrollView(
            key: const PageStorageKey<String>('mobile:follow:list'),
            onRefresh: onRefresh!,
            controller: scrollController,
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: <Widget>[sliver],
          ),
      enableRefresh: true,
      onRefreshFailure: (_) => showToast('刷新失败'),
    );
  }
}
