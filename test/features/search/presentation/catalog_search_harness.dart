import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sakuramedia/features/actors/data/api/actors_api.dart';
import 'package:sakuramedia/features/actors/presentation/actor_subscription_toggle_result.dart';
import 'package:sakuramedia/features/actors/presentation/providers/actors_api_provider.dart';
import 'package:sakuramedia/features/movies/data/api/movies_api.dart';
import 'package:sakuramedia/features/movies/presentation/controllers/listing/movie_filter_state.dart';
import 'package:sakuramedia/features/movies/presentation/movie_subscription_toggle_result.dart';
import 'package:sakuramedia/features/movies/presentation/providers/movies_api_provider.dart';
import 'package:sakuramedia/features/search/presentation/providers/catalog_search_provider.dart';
import 'package:sakuramedia/features/search/presentation/providers/catalog_search_scope.dart';
import 'package:sakuramedia/features/search/presentation/providers/catalog_search_state.dart';

/// 让原控制器语义用 provider 实例验收的最小测试适配层。
class CatalogSearchHarness {
  CatalogSearchHarness({
    required MoviesApi moviesApi,
    required ActorsApi actorsApi,
  }) : _container = ProviderContainer(
         overrides: [
           moviesApiProvider.overrideWithValue(moviesApi),
           actorsApiProvider.overrideWithValue(actorsApi),
         ],
         retry: (_, __) => null,
       ) {
    _subscription = _container.listen(
      catalogSearchProvider(_scope),
      (_, __) {},
    );
  }

  static const _scope = CatalogSearchScope('test:catalog-search');

  final ProviderContainer _container;
  late final ProviderSubscription<CatalogSearchState> _subscription;

  CatalogSearchState get _state =>
      _container.read(catalogSearchProvider(_scope));

  String get query => _state.query;
  CatalogSearchKind get activeKind => _state.activeKind;
  bool get isLoading => _state.isLoading;
  bool get isOnlineSearchActive => _state.isOnlineSearchActive;
  String? get errorMessage => _state.errorMessage;
  dynamic get streamStatus => _state.streamStatus;
  List get movieResults => _state.movieResults;
  List get actorResults => _state.actorResults;
  MovieFilterState get movieFilter => _state.movieFilter;
  MovieSortField? get movieSortField => _state.movieSortField;
  SortDirection get movieSortDirection => _state.movieSortDirection;

  bool isMovieSubscriptionUpdating(String movieNumber) =>
      _state.isMovieSubscriptionUpdating(movieNumber);

  bool isActorSubscriptionUpdating(int actorId) =>
      _state.isActorSubscriptionUpdating(actorId);

  Future<void> submit(String query, {required bool useOnlineSearch}) =>
      _container
          .read(catalogSearchProvider(_scope).notifier)
          .submit(query, useOnlineSearch: useOnlineSearch);

  void setActiveKind(CatalogSearchKind kind) => _container
      .read(catalogSearchProvider(_scope).notifier)
      .setActiveKind(kind);

  Future<void> applyMovieFilter(MovieFilterState filter) => _container
      .read(catalogSearchProvider(_scope).notifier)
      .applyMovieFilter(filter);

  Future<void> setMovieSort({
    required MovieSortField? field,
    required SortDirection direction,
  }) => _container
      .read(catalogSearchProvider(_scope).notifier)
      .setMovieSort(field: field, direction: direction);

  Future<MovieSubscriptionToggleResult> toggleMovieSubscription({
    required String movieNumber,
  }) => _container
      .read(catalogSearchProvider(_scope).notifier)
      .toggleMovieSubscription(movieNumber);

  Future<ActorSubscriptionToggleResult> toggleActorSubscription({
    required int actorId,
  }) => _container
      .read(catalogSearchProvider(_scope).notifier)
      .toggleActorSubscription(actorId);

  void applyMovieSubscriptionChange({
    required String movieNumber,
    required bool isSubscribed,
    bool removeIfUnsubscribed = false,
  }) => _container
      .read(catalogSearchProvider(_scope).notifier)
      .applyMovieSubscriptionChange(
        movieNumber: movieNumber,
        isSubscribed: isSubscribed,
        removeIfUnsubscribed: removeIfUnsubscribed,
      );

  void dispose() {
    _subscription.close();
    _container.dispose();
  }
}
