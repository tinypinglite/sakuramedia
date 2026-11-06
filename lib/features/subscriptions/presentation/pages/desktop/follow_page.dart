import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/features/movies/presentation/pages/shared/movie_summary_list_content.dart';
import 'package:sakuramedia/features/movies/presentation/providers/movie_summary_scope.dart';
import 'package:sakuramedia/l10n/app_localizations.dart';
import 'package:sakuramedia/routes/app_navigation.dart';
import 'package:sakuramedia/routes/app_routes.dart';
import 'package:sakuramedia/theme.dart';

/// 桌面端「女优上新」全量列表页：订阅女优的最近影片。
class DesktopFollowPage extends StatelessWidget {
  const DesktopFollowPage({super.key});

  static const _scope = MovieSummaryScope.subscribedActorsLatest();

  @override
  Widget build(BuildContext context) {
    return MovieSummaryListContent(
      scope: _scope,
      surfaceColor: context.appColors.surfaceElevated,
      contentKey: const Key('desktop-follow-page'),
      sectionSpacing: context.appSpacing.lg,
      registerPageRefresh: true,
      showHeader: false,
      emptyMessage: AppLocalizations.of(context).subscriptionFollowEmpty,
      onMovieTap: (context, movieNumber) => DesktopRoutes.movieDetail(
        movieNumber: movieNumber,
        fallbackPath: desktopFollowPath,
      ).push(context),
      bodyBuilder: (context, scrollController, sliver, _) =>
          CustomScrollView(controller: scrollController, slivers: [sliver]),
    );
  }
}
