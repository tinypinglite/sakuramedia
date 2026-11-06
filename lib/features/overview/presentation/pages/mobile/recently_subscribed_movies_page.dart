import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/widgets/base/feedback/app_toast.dart';
import 'package:sakuramedia/features/movies/presentation/pages/shared/movie_summary_list_content.dart';
import 'package:sakuramedia/features/movies/presentation/providers/movie_summary_scope.dart';
import 'package:sakuramedia/l10n/app_localizations.dart';
import 'package:sakuramedia/routes/mobile_routes.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/layout/scrolling/app_adaptive_refresh_scroll_view.dart';

/// 移动端「最近订阅」全量列表页：概览「我的」tab 分区的「更多」落点。
///
/// 顶栏（标题 + 返回）由 `MobileRecentlySubscribedMoviesRouteData` 的二级页壳提供。
class MobileRecentlySubscribedMoviesPage extends StatelessWidget {
  const MobileRecentlySubscribedMoviesPage({super.key});

  // 与概览「最近订阅」分区用同一 scope（默认 pageSize），共享 provider 实例，
  // 避免从分区进「更多」时用不同 pageSize 再拉一份首页数据。
  static const _scope = MovieSummaryScope.recentlySubscribed();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return MovieSummaryListContent(
      scope: _scope,
      surfaceColor: context.appColors.surfaceCard,
      contentKey: const Key('mobile-recently-subscribed-movies-page'),
      sectionSpacing: context.appSpacing.md,
      emptyMessage: l10n.overviewNoSubscribedMovies,
      onMovieTap: (context, movieNumber) =>
          MobileMovieDetailRouteData(movieNumber: movieNumber).push(context),
      showHeader: false,
      useMobileSelectionLayout: true,
      bodyBuilder: (context, scrollController, sliver, onRefresh) =>
          AppAdaptiveRefreshScrollView(
            key: const PageStorageKey<String>(
              'mobile:recently-subscribed:list',
            ),
            onRefresh: onRefresh!,
            controller: scrollController,
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: <Widget>[sliver],
          ),
      enableRefresh: true,
      onRefreshFailure: (_) =>
          showToast(l10n.overviewRefreshFailed, tone: AppToastTone.error),
    );
  }
}
