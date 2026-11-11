import 'package:sakuramedia/features/status/presentation/providers/server_capabilities_provider.dart';
import 'package:flutter_riverpod/misc.dart' show KeepAliveLink;
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:sakuramedia/app/language/providers/app_localizations_provider.dart';
import 'package:sakuramedia/core/network/api_exception.dart';
import 'package:sakuramedia/features/movies/data/dto/detail/movie_detail_dto.dart';
import 'package:sakuramedia/features/movies/data/dto/listing/movie_list_item_dto.dart';
import 'package:sakuramedia/features/movies/presentation/providers/movie_detail_state.dart';
import 'package:sakuramedia/features/movies/presentation/providers/mutation_events_provider.dart';
import 'package:sakuramedia/features/movies/presentation/providers/movies_api_provider.dart';
import 'package:sakuramedia/features/recent_views/data/dto/recent_view_dto.dart';
import 'package:sakuramedia/features/recent_views/presentation/recent_view_reporter.dart';

export 'package:sakuramedia/features/movies/presentation/providers/movie_detail_state.dart';

part 'movie_detail_provider.g.dart';

/// 影片详情 provider —— autoDispose family (movieNumber) + `cacheLink` 挂
/// [RiverpodPageCache]，跨导航保活。
///
/// 页面进入时显式调用 [load]，并行加载影片详情和相似影片；[refresh] 保留当前
/// 详情内容并重新请求；[applyMovie] 用外部拿到的新 DTO 就地更新影片信息。
///
/// - `load()` 冷启动（无缓存影片）时清空旧的相似影片与错误状态，并行拉取
///   detail / 相似影片；失败时写入 `errorMessage`。暖重进（保活命中已有影片）
///   时走静默刷新：不置 `isLoading`、不清空列表，失败保留旧内容。
/// - `refresh()` 不置 `isLoading`（统计条不闪骨架），并行重拉后原地写入；
///   相似影片仍先置 `isSimilarMoviesLoading` 再写。
/// - `retryLoadSimilarMovies()`：仅重拉相似影片，不清列表。
@riverpod
class MovieDetail extends _$MovieDetail {
  bool _isDisposed = false;
  KeepAliveLink? _cacheLink;
  Future<void>? _refreshInFlight;

  @override
  MovieDetailState build(String movieNumber) {
    ref.onDispose(() {
      _isDisposed = true;
      _cacheLink?.close();
      _cacheLink = null;
    });
    _cacheLink ??= ref.keepAlive();
    ref.listen(movieSubscriptionEventsProvider, (_, next) {
      final changes = next.value;
      if (changes != null) {
        _applySimilarMovieSubscriptionChanges(changes);
      }
    });
    // 组件 mount 后由页面显式调 [load]；provider 自身不预取，避免 hover / watch
    // 即请求。
    return MovieDetailState.initial;
  }

  /// 页面接线 [RiverpodPageCache.obtain] 时收集的 keepAlive link。
  KeepAliveLink? get cacheLink => _cacheLink;

  /// 页面进入时调用：冷启动（无缓存影片）走骨架加载；暖重进（保活命中，
  /// [RiverpodPageCache] 跨导航留住了 `movie`）走静默刷新——不置 `isLoading`、
  /// 不清空已展示的相似影片，旧内容常驻直到新数据到达。
  ///
  /// 全站统一规则：保活 provider 的首载必须暖保护，整页骨架只在无数据时出现。
  /// 暖路径失败时保留旧内容（不覆盖 `errorMessage`）；明确的手动刷新走 [refresh]。
  Future<void> load() async {
    if (_isDisposed) return;
    if (state.movie != null) {
      try {
        await refresh();
      } catch (_) {
        // 暖重进的后台同步失败：保留旧内容，不打扰用户。
        return;
      }
      // 与过去每次进入都上报保持一致：静默刷新成功也计一次浏览。
      reportView();
      return;
    }
    state = state.copyWith(
      isLoading: true,
      errorMessage: null,
      similarMoviesErrorMessage: null,
      isSimilarMoviesLoading: true,
      similarMovies: const <MovieListItemDto>[],
    );

    final similarFuture = _loadSimilarMovies(clearExisting: true);

    try {
      final movie = await ref
          .read(moviesApiProvider)
          .getMovieDetail(movieNumber: movieNumber);
      if (_isDisposed) return;
      reportRecentView(
        ref,
        entityType: RecentViewEntityType.movie,
        entityId: movie.id,
      );
      state = state.copyWith(
        movie: movie,
        selectedPreview: _defaultPreviewFor(movie),
        errorMessage: null,
      );
    } catch (error) {
      if (_isDisposed) return;
      state = state.copyWith(
        movie: null,
        selectedPreview: const MovieDetailPreview.placeholder(),
        errorMessage: _messageForError(error),
      );
    } finally {
      if (!_isDisposed) {
        state = state.copyWith(isLoading: false);
      }
    }

    await similarFuture;
  }

  /// 并发去重：暖重进 [load] 与其他显式刷新（如删媒体后同步）可能同时触发；
  /// 共享在途 Future，避免两个请求乱序返回时旧响应覆盖新响应。
  Future<void> refresh() => _refreshInFlight ??= _refresh().whenComplete(
    () => _refreshInFlight = null,
  );

  Future<void> _refresh() async {
    if (_isDisposed || state.isLoading) return;
    final similarFuture = _loadSimilarMovies();
    final movie = await ref
        .read(moviesApiProvider)
        .getMovieDetail(movieNumber: movieNumber);
    if (_isDisposed) return;
    state = state.copyWith(
      movie: movie,
      selectedPreview: _defaultPreviewFor(movie),
      errorMessage: null,
    );
    await similarFuture;
  }

  /// 详情内删媒体等同步动作在 [refresh] 成功后显式调用。
  ///
  /// [refresh] 自身不上报：媒体管理页删版本等后台同步也走它，若在内部上报，
  /// 用户没打开的影片会被顶进「最近浏览」。
  void reportView() {
    if (_isDisposed) return;
    final movie = state.movie;
    if (movie == null) return;
    reportRecentView(
      ref,
      entityType: RecentViewEntityType.movie,
      entityId: movie.id,
    );
  }

  /// 外部拿到新 DTO 后就地写入，避免重新请求详情。
  void applyMovie(MovieDetailDto movie, {bool resetPreview = false}) {
    if (_isDisposed) return;
    state = state.copyWith(
      movie: movie,
      selectedPreview: resetPreview
          ? _defaultPreviewFor(movie)
          : _resolveUpdatedPreview(movie),
      errorMessage: null,
    );
  }

  Future<void> retryLoadSimilarMovies() =>
      _loadSimilarMovies(clearExisting: false);

  void _applySimilarMovieSubscriptionChanges(
    List<MovieSubscriptionChange> changes,
  ) {
    final statuses = <String, bool>{
      for (final change in changes) change.movieNumber: change.isSubscribed,
    };
    var changed = false;
    final similarMovies = state.similarMovies
        .map((movie) {
          final isSubscribed = statuses[movie.movieNumber];
          if (isSubscribed == null || isSubscribed == movie.isSubscribed) {
            return movie;
          }
          changed = true;
          return movie.copyWithSubscriptionStatus(isSubscribed);
        })
        .toList(growable: false);
    if (changed) {
      state = state.copyWith(similarMovies: similarMovies);
    }
  }

  Future<void> _loadSimilarMovies({bool clearExisting = false}) async {
    if (_isDisposed) return;
    state = state.copyWith(
      isSimilarMoviesLoading: true,
      similarMoviesErrorMessage: null,
      similarMovies: clearExisting
          ? const <MovieListItemDto>[]
          : state.similarMovies,
    );

    try {
      final capabilities = await ref.read(serverCapabilitiesProvider.future);
      if (_isDisposed) return;
      if (!capabilities.movieSimilarity) {
        state = state.copyWith(similarMovies: const <MovieListItemDto>[]);
        return;
      }
      final movies = await ref
          .read(moviesApiProvider)
          .getSimilarMovies(movieNumber: movieNumber, limit: 15);
      if (_isDisposed) return;
      state = state.copyWith(
        similarMovies: movies.take(15).toList(growable: false),
        similarMoviesErrorMessage: null,
      );
    } catch (_) {
      if (_isDisposed) return;
      state = state.copyWith(
        similarMoviesErrorMessage: ref
            .read(appLocalizationsProvider)
            .movieProviderSimilarMoviesLoadFailed,
      );
    } finally {
      if (!_isDisposed) {
        state = state.copyWith(isSimilarMoviesLoading: false);
      }
    }
  }

  MovieDetailPreview _defaultPreviewFor(MovieDetailDto movie) {
    final coverUrl = movie.coverImage?.origin ?? '';
    if (coverUrl.isNotEmpty) {
      return MovieDetailPreview.cover(url: coverUrl);
    }
    return const MovieDetailPreview.placeholder();
  }

  MovieDetailPreview _resolveUpdatedPreview(MovieDetailDto movie) {
    if (state.selectedPreview.key == 'cover') {
      final coverUrl = movie.coverImage?.origin ?? '';
      if (coverUrl.isNotEmpty) {
        return MovieDetailPreview.cover(url: coverUrl);
      }
    }
    return _defaultPreviewFor(movie);
  }

  String _messageForError(Object error) {
    final l10n = ref.read(appLocalizationsProvider);
    if (error is ApiException &&
        (error.statusCode == 404 || error.error?.code == 'movie_not_found')) {
      return l10n.movieProviderMovieNotFound;
    }
    return l10n.movieProviderMovieDetailLoadFailed;
  }
}
