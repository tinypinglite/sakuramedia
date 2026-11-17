import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/widgets/base/feedback/app_toast.dart';
import 'package:sakuramedia/features/movies/presentation/pages/shared/movie_summary_list_content.dart';
import 'package:sakuramedia/features/movies/presentation/providers/movie_summary_scope.dart';
import 'package:sakuramedia/l10n/app_localizations.dart';
import 'package:sakuramedia/routes/app_routes.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/layout/scrolling/app_adaptive_refresh_scroll_view.dart';

class MobileFollowPage extends StatelessWidget {
  const MobileFollowPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return MovieSummaryListContent(
      scope: MovieSummaryScope.subscribedActorsLatest(
        pageSize: 18,
        initialLoadErrorTextOverride: l10n.subscriptionFollowLoadFailed,
      ),
      surfaceColor: context.appColors.surfaceCard,
      contentKey: const Key('mobile-follow-page'),
      sectionSpacing: context.appSpacing.md,
      emptyMessage: l10n.subscriptionFollowEmptyDescription,
      onMovieTap: (context, movieNumber) =>
          MobileRoutes.movieDetail(movieNumber: movieNumber).push(context),
      showHeader: false,
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
      onRefreshFailure: (_) =>
          showToast(l10n.subscriptionRefreshFailed, tone: AppToastTone.error),
    );
  }
}
