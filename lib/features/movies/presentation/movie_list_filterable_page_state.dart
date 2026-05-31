import 'package:sakuramedia/features/movies/presentation/movie_filter_state.dart';
import 'package:sakuramedia/features/movies/presentation/movie_subscription_change_notifier.dart';
import 'package:sakuramedia/features/movies/presentation/paged_movie_summary_controller.dart';

/// `MovieListContent` 渲染所需的最小页面状态契约：分页控制器 + 可读写筛选状态。
///
/// 影片页（[MovieListPageStateEntry]）与标签页（`TagsPageStateEntry`）都实现它，
/// 从而复用同一套列表呈现逻辑。
abstract class MovieListFilterablePageState {
  PagedMovieSummaryController get controller;
  MovieFilterState get filterState;
  set filterState(MovieFilterState value);
}

/// 影片列表订阅变更同步：把全局订阅通知应用到本地分页控制器，并把控制器内的
/// 订阅操作回报给全局通知器。被影片页与标签页共用，避免逐字重复同一套接线。
mixin MovieListSubscriptionSyncMixin {
  PagedMovieSummaryController get controller;
  MovieFilterState get filterState;
  MovieSubscriptionChangeNotifier get subscriptionChangeNotifier;

  void bindSubscriptionSync() {
    subscriptionChangeNotifier.addListener(_onMovieSubscriptionChanged);
  }

  void unbindSubscriptionSync() {
    subscriptionChangeNotifier.removeListener(_onMovieSubscriptionChanged);
  }

  void _onMovieSubscriptionChanged() {
    final change = subscriptionChangeNotifier.lastChange;
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

  void reportSubscriptionChange({
    required String movieNumber,
    required bool isSubscribed,
  }) {
    subscriptionChangeNotifier.reportChange(
      movieNumber: movieNumber,
      isSubscribed: isSubscribed,
    );
  }
}
