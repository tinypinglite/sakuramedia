import 'package:sakuramedia/app/app_page_state_cache.dart';
import 'package:sakuramedia/features/movies/data/movies_api.dart';
import 'package:sakuramedia/features/movies/presentation/movie_filter_state.dart';
import 'package:sakuramedia/features/movies/presentation/paged_movie_summary_controller.dart';

class MovieListPageStateEntry implements AppPageStateEntry {
  MovieListPageStateEntry({required MoviesApi moviesApi})
    : _moviesApi = moviesApi {
    controller = PagedMovieSummaryController(
      fetchPage:
          (page, pageSize) => _moviesApi.getMovies(
            page: page,
            pageSize: pageSize,
            status: filterState.status,
            collectionType: filterState.collectionType,
            sort: filterState.sortExpression,
          ),
      subscribeMovie: _moviesApi.subscribeMovie,
      unsubscribeMovie: _moviesApi.unsubscribeMovie,
      pageSize: 24,
      loadMoreTriggerOffset: 300,
      initialLoadErrorText: '影片列表加载失败，请稍后重试',
      loadMoreErrorText: '加载更多失败，请点击重试',
    );
    controller.attachScrollListener();
    controller.initialize();
  }

  final MoviesApi _moviesApi;
  late final PagedMovieSummaryController controller;
  MovieFilterState filterState = MovieFilterState.initial;

  @override
  void dispose() {
    controller.dispose();
  }
}
