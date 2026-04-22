import 'package:sakuramedia/app/app_page_state_cache.dart';
import 'package:sakuramedia/features/movies/data/movies_api.dart';
import 'package:sakuramedia/features/movies/presentation/movie_subscription_change_notifier.dart';
import 'package:sakuramedia/features/movies/presentation/movie_filter_state.dart';
import 'package:sakuramedia/features/movies/presentation/paged_movie_summary_controller.dart';

class MovieListPageStateEntry implements AppPageStateEntry {
  MovieListPageStateEntry({
    required MoviesApi moviesApi,
    required MovieSubscriptionChangeNotifier subscriptionChangeNotifier,
  }) : _moviesApi = moviesApi,
       _subscriptionChangeNotifier = subscriptionChangeNotifier {
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
      onSubscriptionChanged: _reportSubscriptionChange,
      pageSize: 24,
      loadMoreTriggerOffset: 300,
      initialLoadErrorText: '影片列表加载失败，请稍后重试',
      loadMoreErrorText: '加载更多失败，请点击重试',
    );
    _subscriptionChangeNotifier.addListener(_onMovieSubscriptionChanged);
    controller.attachScrollListener();
    controller.initialize();
  }

  final MoviesApi _moviesApi;
  final MovieSubscriptionChangeNotifier _subscriptionChangeNotifier;
  late final PagedMovieSummaryController controller;
  MovieFilterState filterState = MovieFilterState.initial;

  void _onMovieSubscriptionChanged() {
    final change = _subscriptionChangeNotifier.lastChange;
    if (change == null) {
      return;
    }
    controller.applySubscriptionChange(
      movieNumber: change.movieNumber,
      isSubscribed: change.isSubscribed,
      removeIfUnsubscribed:
          !change.isSubscribed &&
          filterState.status == MovieStatusFilter.subscribed,
    );
  }

  void _reportSubscriptionChange({
    required String movieNumber,
    required bool isSubscribed,
  }) {
    _subscriptionChangeNotifier.reportChange(
      movieNumber: movieNumber,
      isSubscribed: isSubscribed,
    );
  }

  @override
  void dispose() {
    _subscriptionChangeNotifier.removeListener(_onMovieSubscriptionChanged);
    controller.dispose();
  }
}
