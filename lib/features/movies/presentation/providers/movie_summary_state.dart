import 'package:flutter/foundation.dart';
import 'package:sakuramedia/features/movies/data/dto/listing/movie_list_item_dto.dart';
import 'package:sakuramedia/features/movies/presentation/controllers/listing/movie_filter_state.dart';
import 'package:sakuramedia/features/movies/presentation/providers/movie_subscription_mutation_mixin.dart';
import 'package:sakuramedia/features/playlists/presentation/controllers/playlist_filter_state.dart';
import 'package:sakuramedia/features/shared/presentation/providers/paged_async_notifier.dart';

/// 影片摘要列表的筛选值。两类筛选共用同一个值对象，以便同一 family 既可服务
/// `/movies`，也可服务播放列表端点，而不把筛选状态留在页面 State 里。
@immutable
class MovieSummaryFilter {
  const MovieSummaryFilter({
    this.movie = MovieFilterState.initial,
    this.playlist = PlaylistFilterState.initial,
    this.tagIds = const <int>[],
    this.tagMatch = TagMatchMode.or,
  });

  static const MovieSummaryFilter initial = MovieSummaryFilter();

  final MovieFilterState movie;
  final PlaylistFilterState playlist;
  final List<int> tagIds;
  final TagMatchMode tagMatch;

  MovieSummaryFilter copyWith({
    MovieFilterState? movie,
    PlaylistFilterState? playlist,
    List<int>? tagIds,
    TagMatchMode? tagMatch,
  }) {
    return MovieSummaryFilter(
      movie: movie ?? this.movie,
      playlist: playlist ?? this.playlist,
      tagIds: List<int>.unmodifiable(tagIds ?? this.tagIds),
      tagMatch: tagMatch ?? this.tagMatch,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is MovieSummaryFilter &&
        movie.matches(other.movie) &&
        playlist.matches(other.playlist) &&
        listEquals(tagIds, other.tagIds) &&
        tagMatch == other.tagMatch;
  }

  @override
  int get hashCode => Object.hash(
    movie.status,
    movie.collectionType,
    movie.numberSource,
    movie.sortField,
    movie.sortDirection,
    movie.year,
    playlist.sortField,
    playlist.sortDirection,
    playlist.resolution,
    Object.hashAll(tagIds),
    tagMatch,
  );
}

@immutable
class MovieSummaryState
    implements SubscriptionMovieListState<MovieSummaryState, MovieListItemDto> {
  const MovieSummaryState({
    required this.paged,
    required this.filter,
    this.subscriptionUpdatingMovieNumbers = const <String>{},
  });

  @override
  final PagedListState<MovieListItemDto> paged;
  final MovieSummaryFilter filter;
  @override
  final Set<String> subscriptionUpdatingMovieNumbers;

  bool isSubscriptionUpdating(String movieNumber) =>
      subscriptionUpdatingMovieNumbers.contains(movieNumber);

  MovieSummaryState copyWith({
    PagedListState<MovieListItemDto>? paged,
    MovieSummaryFilter? filter,
    Set<String>? subscriptionUpdatingMovieNumbers,
  }) {
    return MovieSummaryState(
      paged: paged ?? this.paged,
      filter: filter ?? this.filter,
      subscriptionUpdatingMovieNumbers: Set<String>.unmodifiable(
        subscriptionUpdatingMovieNumbers ??
            this.subscriptionUpdatingMovieNumbers,
      ),
    );
  }

  @override
  MovieSummaryState applySubscriptionMutation({
    PagedListState<MovieListItemDto>? paged,
    Set<String>? subscriptionUpdatingMovieNumbers,
  }) => copyWith(
    paged: paged,
    subscriptionUpdatingMovieNumbers: subscriptionUpdatingMovieNumbers,
  );
}
