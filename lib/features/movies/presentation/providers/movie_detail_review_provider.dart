import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/misc.dart' show KeepAliveLink;
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:sakuramedia/core/network/api_error_message.dart';
import 'package:sakuramedia/features/movies/data/dto/detail/movie_review_dto.dart';
import 'package:sakuramedia/features/movies/presentation/providers/movies_api_provider.dart';
import 'package:sakuramedia/features/shared/presentation/providers/paged_async_notifier.dart';

part 'movie_detail_review_provider.g.dart';

/// 影片评论区状态（自写分页，非 `PagedAsyncNotifierMixin`）。排序切换同步更新
/// 选中态、保留旧评论并通过共享防抖器刷新第一页。迁移前对应
/// `MovieDetailReviewController extends ChangeNotifier with DisposeSafeNotifier`,
/// 由 `movie_detail_inspector_panel.dart` initState 里 new 出。
@immutable
class MovieDetailReviewState {
  const MovieDetailReviewState({
    this.sort = MovieReviewSort.hotly,
    this.items = const <MovieReviewDto>[],
    this.isInitialLoading = false,
    this.isLoadingMore = false,
    this.hasNextPage = true,
    this.loadedPage = 0,
    this.initialErrorMessage,
    this.loadMoreErrorMessage,
    this.filterUpdate = const FilterUpdateState.idle(),
  });

  static const MovieDetailReviewState initial = MovieDetailReviewState();

  final MovieReviewSort sort;
  final List<MovieReviewDto> items;
  final bool isInitialLoading;
  final bool isLoadingMore;
  final bool hasNextPage;
  final int loadedPage;
  final String? initialErrorMessage;
  final String? loadMoreErrorMessage;
  final FilterUpdateState filterUpdate;

  MovieDetailReviewState copyWith({
    MovieReviewSort? sort,
    List<MovieReviewDto>? items,
    bool? isInitialLoading,
    bool? isLoadingMore,
    bool? hasNextPage,
    int? loadedPage,
    Object? initialErrorMessage = _sentinel,
    Object? loadMoreErrorMessage = _sentinel,
    FilterUpdateState? filterUpdate,
  }) {
    return MovieDetailReviewState(
      sort: sort ?? this.sort,
      items: items ?? this.items,
      isInitialLoading: isInitialLoading ?? this.isInitialLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      hasNextPage: hasNextPage ?? this.hasNextPage,
      loadedPage: loadedPage ?? this.loadedPage,
      initialErrorMessage: identical(initialErrorMessage, _sentinel)
          ? this.initialErrorMessage
          : initialErrorMessage as String?,
      loadMoreErrorMessage: identical(loadMoreErrorMessage, _sentinel)
          ? this.loadMoreErrorMessage
          : loadMoreErrorMessage as String?,
      filterUpdate: filterUpdate ?? this.filterUpdate,
    );
  }
}

const Object _sentinel = Object();

@riverpod
class MovieDetailReview extends _$MovieDetailReview {
  static const int _pageSize = 20;

  bool _isDisposed = false;
  int _contentGeneration = 0;
  KeepAliveLink? _cacheLink;
  late final DebouncedLatestRequest _filterRequests = DebouncedLatestRequest();

  @override
  MovieDetailReviewState build(String movieNumber) {
    ref.onDispose(() {
      _isDisposed = true;
      _filterRequests.dispose();
      _cacheLink?.close();
      _cacheLink = null;
    });
    _cacheLink ??= ref.keepAlive();
    return MovieDetailReviewState.initial;
  }

  KeepAliveLink? get cacheLink => _cacheLink;

  Future<void> loadInitial() async {
    if (_isDisposed || state.isInitialLoading) return;

    _filterRequests.cancel();
    final generation = ++_contentGeneration;
    final sort = state.sort;

    state = state.copyWith(
      isInitialLoading: true,
      initialErrorMessage: null,
      loadMoreErrorMessage: null,
      filterUpdate: const FilterUpdateState.idle(),
    );

    try {
      final reviews = await ref
          .read(moviesApiProvider)
          .getMovieReviews(
            movieNumber: movieNumber,
            page: 1,
            pageSize: _pageSize,
            sort: sort,
          );
      if (_isDisposed ||
          generation != _contentGeneration ||
          state.sort != sort) {
        return;
      }
      state = state.copyWith(
        items: reviews,
        loadedPage: 1,
        hasNextPage: reviews.length >= _pageSize,
        initialErrorMessage: null,
      );
    } catch (error) {
      if (_isDisposed || generation != _contentGeneration) return;
      state = state.copyWith(
        items: const <MovieReviewDto>[],
        loadedPage: 0,
        hasNextPage: true,
        initialErrorMessage: apiErrorMessage(error, fallback: '评论加载失败，请稍后重试。'),
      );
    } finally {
      if (!_isDisposed && generation == _contentGeneration) {
        state = state.copyWith(isInitialLoading: false);
      }
    }
  }

  Future<void> setSort(MovieReviewSort nextSort) {
    if (_isDisposed || state.sort == nextSort) return Future<void>.value();
    _contentGeneration++;
    state = state.copyWith(
      sort: nextSort,
      isLoadingMore: false,
      loadMoreErrorMessage: null,
      filterUpdate: const FilterUpdateState.waiting(),
    );
    return _filterRequests.schedule(_loadSortedFirstPage);
  }

  Future<void> retrySort() {
    if (_isDisposed) return Future<void>.value();
    _contentGeneration++;
    state = state.copyWith(
      isLoadingMore: false,
      loadMoreErrorMessage: null,
      filterUpdate: const FilterUpdateState.loading(),
    );
    return _filterRequests.runNow(_loadSortedFirstPage);
  }

  Future<void> _loadSortedFirstPage(int requestId) async {
    final sort = state.sort;
    if (_isDisposed || !_filterRequests.isCurrent(requestId)) return;
    state = state.copyWith(filterUpdate: const FilterUpdateState.loading());
    try {
      final reviews = await ref
          .read(moviesApiProvider)
          .getMovieReviews(
            movieNumber: movieNumber,
            page: 1,
            pageSize: _pageSize,
            sort: sort,
          );
      if (_isDisposed ||
          !_filterRequests.isCurrent(requestId) ||
          state.sort != sort) {
        return;
      }
      state = state.copyWith(
        items: reviews,
        isInitialLoading: false,
        loadedPage: 1,
        hasNextPage: reviews.length >= _pageSize,
        initialErrorMessage: null,
        loadMoreErrorMessage: null,
        filterUpdate: const FilterUpdateState.idle(),
      );
    } catch (error) {
      if (_isDisposed || !_filterRequests.isCurrent(requestId)) return;
      state = state.copyWith(
        isInitialLoading: false,
        filterUpdate: FilterUpdateState.failed(
          apiErrorMessage(error, fallback: '评论筛选更新失败，请稍后重试。'),
        ),
      );
    }
  }

  Future<void> loadMore() async {
    if (_isDisposed ||
        state.isInitialLoading ||
        state.isLoadingMore ||
        !state.filterUpdate.isIdle ||
        !state.hasNextPage ||
        state.items.isEmpty) {
      return;
    }

    state = state.copyWith(isLoadingMore: true, loadMoreErrorMessage: null);

    final generation = _contentGeneration;
    final sort = state.sort;
    final nextPage = state.loadedPage + 1;
    try {
      final reviews = await ref
          .read(moviesApiProvider)
          .getMovieReviews(
            movieNumber: movieNumber,
            page: nextPage,
            pageSize: _pageSize,
            sort: sort,
          );
      if (_isDisposed ||
          generation != _contentGeneration ||
          state.sort != sort) {
        return;
      }
      if (reviews.isEmpty) {
        state = state.copyWith(hasNextPage: false);
      } else {
        state = state.copyWith(
          items: <MovieReviewDto>[...state.items, ...reviews],
          loadedPage: nextPage,
          hasNextPage: reviews.length >= _pageSize,
          loadMoreErrorMessage: null,
        );
      }
    } catch (error) {
      if (_isDisposed || generation != _contentGeneration) return;
      state = state.copyWith(
        loadMoreErrorMessage: apiErrorMessage(
          error,
          fallback: '评论加载更多失败，请稍后重试。',
        ),
      );
    } finally {
      if (!_isDisposed && generation == _contentGeneration) {
        state = state.copyWith(isLoadingMore: false);
      }
    }
  }
}
