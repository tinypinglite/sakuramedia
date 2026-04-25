import 'package:flutter/material.dart';
import 'package:oktoast/oktoast.dart';
import 'package:sakuramedia/features/movies/presentation/series_movies_content.dart';
import 'package:sakuramedia/routes/mobile_routes.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/app_adaptive_refresh_scroll_view.dart';

class MobileSeriesMoviesPage extends StatelessWidget {
  const MobileSeriesMoviesPage({
    super.key,
    required this.seriesId,
    this.seriesName,
  });

  final int seriesId;
  final String? seriesName;

  @override
  Widget build(BuildContext context) {
    return SeriesMoviesContent(
      seriesId: seriesId,
      initialSeriesName: seriesName,
      surfaceColor: context.appColors.surfaceCard,
      contentKey: const Key('mobile-series-movies-page'),
      totalKey: const Key('mobile-series-movies-total'),
      sectionSpacing: context.appSpacing.md,
      onMovieTap:
          (context, movieNumber) => MobileMovieDetailRouteData(
            movieNumber: movieNumber,
          ).push(context),
      bodyBuilder:
          (context, scrollController, child, onRefresh) =>
              AppAdaptiveRefreshScrollView(
                onRefresh: onRefresh!,
                controller: scrollController,
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: <Widget>[SliverToBoxAdapter(child: child)],
              ),
      enableRefresh: true,
      onRefreshFailure: (_) => showToast('刷新失败'),
    );
  }
}
