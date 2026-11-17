import 'package:sakuramedia/features/discovery/data/hot_actress_release_movie_dto.dart';
import 'package:sakuramedia/features/movies/presentation/controllers/notifiers/movie_subscription_change.dart';

/// 将跨页订阅变更映射回热门女优推荐的嵌套影片 DTO。
extension HotActressReleaseSubscriptionChanges
    on List<HotActressReleaseMovieDto> {
  List<HotActressReleaseMovieDto> withSubscriptionChanges(
    Iterable<MovieSubscriptionChange> changes,
  ) {
    final subscriptions = <String, bool>{
      for (final change in changes) change.movieNumber: change.isSubscribed,
    };
    if (subscriptions.isEmpty) return this;

    var didPatch = false;
    final items = map((item) {
      final isSubscribed = subscriptions[item.movie.movieNumber];
      if (isSubscribed == null || item.movie.isSubscribed == isSubscribed) {
        return item;
      }
      didPatch = true;
      return item.copyWith(
        movie: item.movie.copyWith(isSubscribed: isSubscribed),
      );
    }).toList(growable: false);
    return didPatch
        ? List<HotActressReleaseMovieDto>.unmodifiable(items)
        : this;
  }
}
