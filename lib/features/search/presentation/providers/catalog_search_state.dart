import 'package:flutter/foundation.dart';
import 'package:sakuramedia/features/actors/data/dto/actor_list_item_dto.dart';
import 'package:sakuramedia/features/movies/data/dto/listing/movie_list_item_dto.dart';
import 'package:sakuramedia/features/movies/presentation/controllers/listing/movie_filter_state.dart';
import 'package:sakuramedia/features/search/presentation/catalog_search_stream_status.dart';

enum CatalogSearchKind { movies, actors }

const MovieFilterState initialCatalogSearchMovieFilter = MovieFilterState(
  collectionType: MovieCollectionTypeFilter.all,
);

@immutable
class CatalogSearchState {
  const CatalogSearchState({
    this.query = '',
    this.activeKind = CatalogSearchKind.movies,
    this.isLoading = false,
    this.isOnlineSearchActive = false,
    this.useOnlineSearch = false,
    this.errorMessage,
    this.streamStatus,
    this.movieResults = const <MovieListItemDto>[],
    this.actorResults = const <ActorListItemDto>[],
    this.movieFilter = initialCatalogSearchMovieFilter,
    this.movieSortField,
    this.movieSortDirection = SortDirection.desc,
    this.updatingMovieNumbers = const <String>{},
    this.updatingActorIds = const <int>{},
    this.hasBootstrapped = false,
  });

  static const CatalogSearchState initial = CatalogSearchState();

  final String query;
  final CatalogSearchKind activeKind;
  final bool isLoading;
  final bool isOnlineSearchActive;
  final bool useOnlineSearch;
  final String? errorMessage;
  final CatalogSearchStreamStatus? streamStatus;
  final List<MovieListItemDto> movieResults;
  final List<ActorListItemDto> actorResults;
  final MovieFilterState movieFilter;
  final MovieSortField? movieSortField;
  final SortDirection movieSortDirection;
  final Set<String> updatingMovieNumbers;
  final Set<int> updatingActorIds;
  final bool hasBootstrapped;

  static bool hasActiveMovieFilterConditions(MovieFilterState filter) =>
      filter.status != MovieStatusFilter.all ||
      filter.collectionType != MovieCollectionTypeFilter.all ||
      filter.numberSource != MovieNumberSourceFilter.all ||
      filter.years.isNotEmpty ||
      !filter.interaction.isDefault ||
      filter.actorAgeMin != null ||
      filter.actorAgeMax != null ||
      filter.resolution != null ||
      filter.mediaTagIds.isNotEmpty;

  bool get hasActiveMovieFilters => hasActiveMovieFilterConditions(movieFilter);

  String? get movieSortExpression {
    final field = movieSortField;
    if (field == null) {
      return null;
    }
    return '${field.apiValue}:${movieSortDirection.apiValue}';
  }

  bool isMovieSubscriptionUpdating(String movieNumber) =>
      updatingMovieNumbers.contains(movieNumber);

  bool isActorSubscriptionUpdating(int actorId) =>
      updatingActorIds.contains(actorId);

  CatalogSearchState copyWith({
    String? query,
    CatalogSearchKind? activeKind,
    bool? isLoading,
    bool? isOnlineSearchActive,
    bool? useOnlineSearch,
    Object? errorMessage = _sentinel,
    Object? streamStatus = _sentinel,
    List<MovieListItemDto>? movieResults,
    List<ActorListItemDto>? actorResults,
    MovieFilterState? movieFilter,
    Object? movieSortField = _sentinel,
    SortDirection? movieSortDirection,
    Set<String>? updatingMovieNumbers,
    Set<int>? updatingActorIds,
    bool? hasBootstrapped,
  }) {
    return CatalogSearchState(
      query: query ?? this.query,
      activeKind: activeKind ?? this.activeKind,
      isLoading: isLoading ?? this.isLoading,
      isOnlineSearchActive: isOnlineSearchActive ?? this.isOnlineSearchActive,
      useOnlineSearch: useOnlineSearch ?? this.useOnlineSearch,
      errorMessage: identical(errorMessage, _sentinel)
          ? this.errorMessage
          : errorMessage as String?,
      streamStatus: identical(streamStatus, _sentinel)
          ? this.streamStatus
          : streamStatus as CatalogSearchStreamStatus?,
      movieResults: List<MovieListItemDto>.unmodifiable(
        movieResults ?? this.movieResults,
      ),
      actorResults: List<ActorListItemDto>.unmodifiable(
        actorResults ?? this.actorResults,
      ),
      movieFilter: movieFilter ?? this.movieFilter,
      movieSortField: identical(movieSortField, _sentinel)
          ? this.movieSortField
          : movieSortField as MovieSortField?,
      movieSortDirection: movieSortDirection ?? this.movieSortDirection,
      updatingMovieNumbers: Set<String>.unmodifiable(
        updatingMovieNumbers ?? this.updatingMovieNumbers,
      ),
      updatingActorIds: Set<int>.unmodifiable(
        updatingActorIds ?? this.updatingActorIds,
      ),
      hasBootstrapped: hasBootstrapped ?? this.hasBootstrapped,
    );
  }
}

const Object _sentinel = Object();
