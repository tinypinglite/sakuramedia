import 'package:flutter_riverpod/misc.dart' show KeepAliveLink;
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:sakuramedia/app/language/providers/app_localizations_provider.dart';
import 'package:sakuramedia/core/network/paginated_response_dto.dart';
import 'package:sakuramedia/features/actors/presentation/providers/actor_subscription_events_provider.dart';
import 'package:sakuramedia/features/movies/data/dto/detail/movie_collection_type_dto.dart';
import 'package:sakuramedia/features/movies/data/dto/listing/movie_list_item_dto.dart';
import 'package:sakuramedia/features/movies/presentation/controllers/listing/movie_filter_state.dart';
import 'package:sakuramedia/features/movies/presentation/providers/movie_subscription_mutation_mixin.dart';
import 'package:sakuramedia/features/movies/presentation/providers/movie_summary_scope.dart';
import 'package:sakuramedia/features/movies/presentation/providers/movie_summary_state.dart';
import 'package:sakuramedia/features/movies/presentation/providers/movies_api_provider.dart';
import 'package:sakuramedia/features/movies/presentation/providers/mutation_events_provider.dart';
import 'package:sakuramedia/features/media/presentation/providers/media_tag_assignment_events_provider.dart';
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
  Future<void>? _broadcastRefreshInFlight;

  /// 仅缓存 scope 有值时供页面 LRU 收集；普通波 A 页面仍保持 autoDispose。
  KeepAliveLink? get cacheLink => _cacheLink;

  @override
  bool get isOptimisticPatchDisposed => isDisposed;

  @override
  int get pageSize => scope.pageSize;

  @override
  String get initialLoadErrorText =>
      scope.errorText(ref.read(appLocalizationsProvider));

  @override
  String get loadMoreErrorText =>
      ref.read(appLocalizationsProvider).errorLoadMoreFailed;

  @override
  MovieSummaryFilter get initialFilter => MovieSummaryFilter(
    movie: scope.initialMovieFilter ?? MovieFilterState.initial,
    tagIds: scope.initialTagIds,
    tagMatch: scope.initialTagMatch,
  );

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
        tagIds: filter.tagIds,
        tagMatch: filter.tagMatch,
        mediaTagIds: filter.movie.mediaTagIds,
        mediaTagMatch: filter.movie.mediaTagMatch,
        page: page,
        pageSize: pageSize,
        status: filter.movie.status,
        collectionType: filter.movie.collectionType,
        numberSource: filter.movie.numberSource,
        sort: filter.movie.sortExpression,
        years: filter.movie.years.toList(),
        interaction: filter.movie.interaction,
        actorAgeMin: filter.movie.actorAgeMin,
        actorAgeMax: filter.movie.actorAgeMax,
        resolution: filter.movie.resolution?.apiValue,
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
        years: filter.movie.years.toList(),
        interaction: filter.movie.interaction,
        actorAgeMin: filter.movie.actorAgeMin,
        actorAgeMax: filter.movie.actorAgeMax,
        resolution: filter.movie.resolution?.apiValue,
      ),
      MovieSummarySource.subscribedActorsLatest =>
        moviesApi.getSubscribedActorsLatestMovies(
          page: page,
          pageSize: pageSize,
        ),
      MovieSummarySource.recentlySubscribed => moviesApi.getMovies(
        status: MovieStatusFilter.subscribed,
        sort: 'subscribed_at:desc',
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
        tagIds: filter.tagIds,
        tagMatch: filter.tagMatch,
        page: page,
        pageSize: pageSize,
        status: filter.movie.status,
        collectionType: filter.movie.collectionType,
        numberSource: filter.movie.numberSource,
        sort: filter.movie.sortExpression,
        years: filter.movie.years.toList(),
        interaction: filter.movie.interaction,
        resolution: filter.movie.resolution?.apiValue,
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
      MovieSummarySource.rated => moviesApi.getMovies(
        rated: true,
        sort: filter.movie.sortExpression,
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
      if (changes == null) {
        return;
      }
      applySubscriptionChanges(changes);
      // 「最近订阅」无法凭空插入新订阅的影片（列表里没有行可补丁），
      // 收到订阅广播时暖刷新一次；退订仍走就地移除。
      if (scope.source == MovieSummarySource.recentlySubscribed &&
          changes.any((change) => change.isSubscribed)) {
        _scheduleBroadcastRefresh();
      }
    });
    if (scope.source == MovieSummarySource.subscribedActorsLatest) {
      // 影片行没有演员字段，女优订阅变化无法就地摘除/插入；暖刷新收敛。
      ref.listen(actorSubscriptionEventsProvider, (_, next) {
        if (next.value == null) {
          return;
        }
        _scheduleBroadcastRefresh();
      });
    }
    ref.listen(movieCollectionTypeEventsProvider, (_, next) {
      final change = next.value;
      if (change != null) {
        _applyCollectionTypeChange(change);
      }
    });
    ref.listen(movieMediaEventsProvider, (_, next) {
      final change = next.value;
      if (change != null) {
        _applyMediaChange(change);
      }
    });
    ref.listen(mediaTagAssignmentEventsProvider, (_, next) {
      if (next.value != null && activeFilter.movie.mediaTagIds.isNotEmpty) {
        _scheduleBroadcastRefresh();
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

  /// 广播触发的暖刷新，并发去重（同影片详情的 refresh 语义：共享在途 Future，
  /// 快速连发的广播不会各发一次请求）。
  void _scheduleBroadcastRefresh() {
    _broadcastRefreshInFlight ??= _warmRefreshFromBroadcast().whenComplete(
      () => _broadcastRefreshInFlight = null,
    );
  }

  /// 广播暖刷新：列表还在第一页时走标准 [refresh]（整体替换，顺带收敛本地
  /// 补丁不掉的删除）；已翻到后续页时只把第一页合并进来——直接 [refresh] 会用
  /// 第一页覆盖 `paged`，把「更多」页加载的后续页全部丢掉、滚动位置跳变。
  Future<void> _warmRefreshFromBroadcast() async {
    if (isDisposed) return;
    final current = state.value;
    if (current == null) {
      return;
    }
    if (pagedOf(current).currentPage <= initialPage) {
      await refresh();
      return;
    }
    try {
      final response = await fetchPage(initialPage, pageSize);
      if (isDisposed) return;
      final latest = state.value;
      if (latest == null) return;
      final paged = pagedOf(latest);
      final seen = <String>{for (final item in paged.items) item.movieNumber};
      final fresh = <MovieListItemDto>[
        for (final item in response.items)
          if (seen.add(item.movieNumber)) item,
      ];
      if (fresh.isEmpty && paged.total == response.total) {
        return;
      }
      final items = List<MovieListItemDto>.unmodifiable(<MovieListItemDto>[
        ...fresh,
        ...paged.items,
      ]);
      state = AsyncData(
        applyPaged(
          latest,
          paged.copyWith(
            items: items,
            total: response.total,
            hasMore: items.length < response.total,
            syncedAt: response.syncedAt,
          ),
        ),
      );
    } catch (_) {
      // 暖刷新失败静默：保留现有列表，等下一次广播或用户刷新收敛。
    }
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

  /// 清空标签条件。只服务于把标签当附加筛选的入口（女优详情等）；
  /// 标签页依赖"空标签不请求"语义，不调用本方法。
  Future<void> clearTagFilter() {
    return applyFilterState(
      activeFilter.copyWith(tagIds: const <int>[], tagMatch: TagMatchMode.or),
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

  void _applyMediaChange(MovieMediaChange change) {
    final current = state.value;
    if (current == null) return;
    final filtersByStatus =
        scope.source == MovieSummarySource.actor ||
        scope.source == MovieSummarySource.movies ||
        scope.source == MovieSummarySource.tags;
    final remove =
        filtersByStatus &&
        switch (current.filter.movie.status) {
          MovieStatusFilter.all => false,
          MovieStatusFilter.playable => !change.canPlay,
          MovieStatusFilter.subscribed => !change.isSubscribed,
          MovieStatusFilter.unsubscribed => change.isSubscribed,
        };
    final paged = remove
        ? current.paged.removeWhere(
            (item) => item.movieNumber == change.movieNumber,
          )
        : current.paged.patchWhere(
            (item) =>
                item.movieNumber == change.movieNumber &&
                (item.canPlay != change.canPlay ||
                    item.isSubscribed != change.isSubscribed),
            (item) => item.copyWith(
              canPlay: change.canPlay,
              isSubscribed: change.isSubscribed,
            ),
          );
    if (!identical(paged, current.paged)) {
      state = AsyncData(current.copyWith(paged: paged));
    }
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

  @override
  bool shouldRemoveSubscriptionChange(MovieSubscriptionChange change) {
    // 「最近订阅」是订阅集合语义：退订即不再属于该列表。
    if (scope.source == MovieSummarySource.recentlySubscribed) {
      return !change.isSubscribed;
    }
    // 状态筛选视图：单条心形切换保留行、就地翻态（刷新/重进后自然收敛，
    // 误触可原地点回来）；批量操作是显式清场，把翻转后不再满足条件的行移出。
    if (!change.fromBatch) {
      return false;
    }
    if (scope.source != MovieSummarySource.movies &&
        scope.source != MovieSummarySource.tags &&
        scope.source != MovieSummarySource.actor) {
      return false;
    }
    return switch (activeFilter.movie.status) {
      MovieStatusFilter.subscribed => !change.isSubscribed,
      MovieStatusFilter.unsubscribed => change.isSubscribed,
      _ => false,
    };
  }
}
