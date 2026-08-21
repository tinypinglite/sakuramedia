import 'package:flutter_riverpod/misc.dart' show KeepAliveLink;
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:sakuramedia/core/network/paginated_response_dto.dart';
import 'package:sakuramedia/features/movies/data/dto/listing/movie_list_item_dto.dart';
import 'package:sakuramedia/features/movies/data/dto/detail/movie_collection_type_dto.dart';
import 'package:sakuramedia/features/movies/presentation/controllers/listing/movie_filter_state.dart';
import 'package:sakuramedia/features/movies/presentation/providers/movies_api_provider.dart';
import 'package:sakuramedia/features/movies/presentation/providers/mutation_events_provider.dart';
import 'package:sakuramedia/features/movies/presentation/providers/movie_subscription_mutation_mixin.dart';
import 'package:sakuramedia/features/movies/presentation/providers/movie_summary_scope.dart';
import 'package:sakuramedia/features/movies/presentation/providers/movie_summary_state.dart';
import 'package:sakuramedia/features/playlists/presentation/controllers/playlist_filter_state.dart';
import 'package:sakuramedia/features/playlists/presentation/providers/playlists_api_provider.dart';
import 'package:sakuramedia/features/shared/presentation/providers/optimistic_patch_mixin.dart';
import 'package:sakuramedia/features/shared/presentation/providers/paged_async_notifier.dart';

part 'movie_summary_provider.g.dart';

/// 波 A 的影片摘要分页状态。
///
/// 迁移前的七个非缓存页面各自创建 [PagedMovieSummaryController]，再手工接两个
/// ChangeNotifier 广播。这里以 [MovieSummaryScope] family 保持实例隔离，并把
/// 订阅/合集变更统一收为 `ref.listen` 的不可变本地补丁。
@riverpod
class MovieSummary extends _$MovieSummary
    with
        PagedAsyncNotifierMixin<MovieSummaryState, MovieListItemDto>,
        FilterablePagedAsyncNotifierMixin<
          MovieSummaryState,
          MovieListItemDto,
          MovieSummaryFilter
        >,
        OptimisticPatchMixin<MovieSummaryState>,
        MovieSubscriptionMutationMixin<MovieSummaryState, MovieListItemDto> {
  KeepAliveLink? _cacheLink;

  /// 仅缓存 scope 有值时供页面 LRU 收集；普通波 A 页面仍保持 autoDispose。
  KeepAliveLink? get cacheLink => _cacheLink;

  @override
  bool get isOptimisticPatchDisposed => isDisposed;

  @override
  int get pageSize => scope.pageSize;

  @override
  String get initialLoadErrorText => scope.initialLoadErrorText;

  @override
  String get loadMoreErrorText => '加载更多失败，请点击重试';

  @override
  MovieSummaryFilter get initialFilter => MovieSummaryFilter.initial;

  @override
  PagedListState<MovieListItemDto> pagedOf(MovieSummaryState state) =>
      state.paged;

  @override
  MovieSummaryState applyPaged(
    MovieSummaryState state,
    PagedListState<MovieListItemDto> paged,
  ) => state.copyWith(paged: paged);

  @override
  MovieSummaryState applyFilterToState(
    MovieSummaryState state,
    MovieSummaryFilter filter,
  ) => state.copyWith(filter: filter);

  @override
  Future<PaginatedResponseDto<MovieListItemDto>> fetchPage(
    int page,
    int pageSize,
  ) {
    final filter = activeFilter;
    final moviesApi = ref.read(moviesApiProvider);
    return switch (scope.source) {
      MovieSummarySource.latest => moviesApi.getLatestMovies(
        page: page,
        pageSize: pageSize,
      ),
      MovieSummarySource.movies => moviesApi.getMovies(
        page: page,
        pageSize: pageSize,
        status: filter.movie.status,
        collectionType: filter.movie.collectionType,
        numberSource: filter.movie.numberSource,
        sort: filter.movie.sortExpression,
        year: filter.movie.year,
        heatMin: filter.movie.heatMin,
        heatMax: filter.movie.heatMax,
      ),
      MovieSummarySource.tags => moviesApi.getMovies(
        tagIds: filter.tagIds,
        tagMatch: filter.tagMatch,
        page: page,
        pageSize: pageSize,
        status: filter.movie.status,
        collectionType: filter.movie.collectionType,
        numberSource: filter.movie.numberSource,
        sort: filter.movie.sortExpression,
        year: filter.movie.year,
        heatMin: filter.movie.heatMin,
        heatMax: filter.movie.heatMax,
      ),
      MovieSummarySource.subscribedActorsLatest =>
        moviesApi.getSubscribedActorsLatestMovies(
          page: page,
          pageSize: pageSize,
        ),
      MovieSummarySource.blacklisted => moviesApi.getMovies(
        blacklisted: true,
        page: page,
        pageSize: pageSize,
      ),
      MovieSummarySource.actor => moviesApi.getMovies(
        actorId: scope.resourceId!,
        page: page,
        pageSize: pageSize,
        status: filter.movie.status,
        collectionType: filter.movie.collectionType,
        numberSource: filter.movie.numberSource,
        sort: filter.movie.sortExpression,
        year: filter.movie.year,
        heatMin: filter.movie.heatMin,
        heatMax: filter.movie.heatMax,
      ),
      MovieSummarySource.playlist =>
        ref
            .read(playlistsApiProvider)
            .getPlaylistMovies(
              playlistId: scope.resourceId!,
              page: page,
              pageSize: pageSize,
              sort: filter.playlist.sortExpression,
              resolution: filter.playlist.resolution?.apiValue,
            ),
      MovieSummarySource.series => moviesApi.getMoviesBySeries(
        seriesId: scope.resourceId!,
        page: page,
        pageSize: pageSize,
      ),
    };
  }

  @override
  Future<MovieSummaryState> build(MovieSummaryScope scope) async {
    if (scope.cacheKey != null) {
      // 初始失败后的 reload 会重跑 build；复用首个 link，避免缓存只关掉旧 link。
      _cacheLink ??= ref.keepAlive();
    }
    attachDisposeGuard();
    ref.listen(movieSubscriptionEventsProvider, (_, next) {
      final changes = next.value;
      if (changes != null) {
        applySubscriptionChanges(changes);
      }
    });
    ref.listen(movieCollectionTypeEventsProvider, (_, next) {
      final change = next.value;
      if (change != null) {
        _applyCollectionTypeChange(change);
      }
    });
    if (scope.source == MovieSummarySource.tags &&
        activeFilter.tagIds.isEmpty) {
      return MovieSummaryState(
        paged: const PagedListState<MovieListItemDto>(),
        filter: activeFilter,
      );
    }
    final paged = await loadInitialPage();
    return MovieSummaryState(paged: paged, filter: activeFilter);
  }

  Future<void> applyMovieFilter(MovieFilterState filter) {
    return applyFilterState(activeFilter.copyWith(movie: filter));
  }

  Future<void> applyPlaylistFilter(PlaylistFilterState filter) {
    return applyFilterState(activeFilter.copyWith(playlist: filter));
  }

  Future<void> applyTagFilter({
    required Iterable<int> tagIds,
    required TagMatchMode tagMatch,
  }) {
    final ordered = <int>[];
    final seen = <int>{};
    for (final tagId in tagIds) {
      if (tagId > 0 && seen.add(tagId)) {
        ordered.add(tagId);
      }
    }
    if (ordered.isEmpty) {
      return Future<void>.value();
    }
    return applyFilterState(
      activeFilter.copyWith(tagIds: ordered, tagMatch: tagMatch),
    );
  }

  Future<void> blacklistMovies({required Iterable<String> movieNumbers}) async {
    final ordered = <String>[];
    final seen = <String>{};
    for (final movieNumber in movieNumbers) {
      if (movieNumber.isNotEmpty && seen.add(movieNumber)) {
        ordered.add(movieNumber);
      }
    }
    if (ordered.isEmpty) {
      return;
    }
    await ref
        .read(moviesApiProvider)
        .setMoviesBlacklisted(movieNumbers: ordered, isBlacklisted: true);
    removeMovies(ordered);
  }

  Future<void> unblacklistMovie({required String movieNumber}) async {
    if (movieNumber.isEmpty) {
      return;
    }
    await ref
        .read(moviesApiProvider)
        .setMoviesBlacklisted(
          movieNumbers: <String>[movieNumber],
          isBlacklisted: false,
        );
    removeMovies(<String>[movieNumber]);
  }

  void removeMovies(Iterable<String> movieNumbers) {
    final numbers = movieNumbers.toSet();
    final current = state.value;
    if (numbers.isEmpty || current == null) {
      return;
    }
    final paged = current.paged.removeWhere(
      (item) => numbers.contains(item.movieNumber),
    );
    if (identical(paged, current.paged)) {
      return;
    }
    state = AsyncData(current.copyWith(paged: paged));
  }

  void _applyCollectionTypeChange(MovieCollectionTypeChange change) {
    if (change.targetType != MovieCollectionType.collection ||
        !_removesCollectionMovies) {
      return;
    }
    final current = state.value;
    if (current == null) {
      return;
    }
    final paged = current.paged.removeWhere(
      (item) => item.movieNumber == change.movieNumber,
    );
    if (identical(paged, current.paged)) {
      return;
    }
    state = AsyncData(current.copyWith(paged: paged));
  }

  bool get _removesCollectionMovies {
    return scope.source == MovieSummarySource.subscribedActorsLatest ||
        ((scope.source == MovieSummarySource.movies ||
                scope.source == MovieSummarySource.tags) &&
            activeFilter.movie.collectionType ==
                MovieCollectionTypeFilter.single) ||
        (scope.source == MovieSummarySource.actor &&
            activeFilter.movie.collectionType ==
                MovieCollectionTypeFilter.single);
  }

  bool get _removesSubscriptionFlipRows {
    if (scope.source != MovieSummarySource.movies &&
        scope.source != MovieSummarySource.tags) {
      return false;
    }
    // subscribed 视图：取消订阅的影片不再满足条件；
    // unsubscribed 视图：订阅的影片不再满足条件。两种视图都就地移除翻转行。
    return activeFilter.movie.status == MovieStatusFilter.subscribed ||
        activeFilter.movie.status == MovieStatusFilter.unsubscribed;
  }

  @override
  bool shouldRemoveSubscriptionChange(MovieSubscriptionChange change) =>
      _removesSubscriptionFlipRows &&
      (activeFilter.movie.status == MovieStatusFilter.subscribed
          ? !change.isSubscribed
          : change.isSubscribed);
}
