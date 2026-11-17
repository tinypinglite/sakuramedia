import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/features/movies/presentation/pages/shared/series_movies_content.dart';
import 'package:sakuramedia/routes/app_routes.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/layout/scrolling/app_adaptive_refresh_scroll_view.dart';

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
      contentKey: const Key('mobile-series-movies-page'),
      totalKey: const Key('mobile-series-movies-total'),
      sectionSpacing: context.appSpacing.md,
      onMovieTap: (context, movieNumber) =>
          MobileRoutes.movieDetail(movieNumber: movieNumber).push(context),
      bodyBuilder: (context, scrollController, sliver, onRefresh) =>
          AppAdaptiveRefreshScrollView(
            onRefresh: onRefresh!,
            controller: scrollController,
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: <Widget>[sliver],
          ),
      enableRefresh: true,
      // 与移动影片页同一套移动范式：多选入口挂卡片长按、批量动作下沉到底部条。
      useMobileSelectionLayout: true,
      // 系列名进返回栏——信息槽里会被压成省略号。
      hoistTitleToSubpageShell: true,
    );
  }
}
