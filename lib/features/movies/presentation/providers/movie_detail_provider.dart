import 'package:flutter_riverpod/misc.dart' show KeepAliveLink;
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:sakuramedia/core/network/api_exception.dart';
import 'package:sakuramedia/features/movies/data/dto/detail/movie_detail_dto.dart';
import 'package:sakuramedia/features/movies/data/dto/listing/movie_list_item_dto.dart';
import 'package:sakuramedia/features/movies/presentation/providers/movie_detail_state.dart';
import 'package:sakuramedia/features/movies/presentation/providers/movies_api_provider.dart';

export 'package:sakuramedia/features/movies/presentation/providers/movie_detail_state.dart';

part 'movie_detail_provider.g.dart';

/// 影片详情 provider —— autoDispose family (movieNumber) + `cacheLink` 挂
/// [RiverpodPageCache]，跨导航保活。
///
/// 页面进入时显式调用 [load]，并行加载影片详情和相似影片；[refresh] 保留当前
/// 详情内容并重新请求；[applyMovie] 用外部拿到的新 DTO 就地更新影片信息。
///
/// - `load()` 会清空旧的相似影片与错误状态，并行拉取 detail / 相似影片；失败时
///   写入 `errorMessage`。
/// - `refresh()` 不置 `isLoading`（统计条不闪骨架），并行重拉后原地写入；
///   相似影片仍先置 `isSimilarMoviesLoading` 再写。
/// - `retryLoadSimilarMovies()`：仅重拉相似影片，不清列表。
@riverpod
class MovieDetail extends _$MovieDetail {
  bool _isDisposed = false;
  KeepAliveLink? _cacheLink;

  @override
  MovieDetailState build(String movieNumber) {
    ref.onDispose(() {
      _isDisposed = true;
      _cacheLink?.close();
      _cacheLink = null;
    });
    _cacheLink ??= ref.keepAlive();
    // 组件 mount 后由页面显式调 [load]；provider 自身不预取，避免 hover / watch
    // 即请求。
    return MovieDetailState.initial;
  }

  /// 页面接线 [RiverpodPageCache.obtain] 时收集的 keepAlive link。
  KeepAliveLink? get cacheLink => _cacheLink;

  Future<void> load() async {
    if (_isDisposed) return;
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

  Future<void> refresh() async {
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

  /// 外部拿到新 DTO 后就地写入（如 refreshMetadata 成功回写）。
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
      state = state.copyWith(similarMoviesErrorMessage: '相似影片暂时无法加载，请稍后重试');
    } finally {
      if (!_isDisposed) {
        state = state.copyWith(isSimilarMoviesLoading: false);
      }
    }
  }

  MovieDetailPreview _defaultPreviewFor(MovieDetailDto movie) {
    final coverUrl = movie.coverImage?.bestAvailableUrl ?? '';
    if (coverUrl.isNotEmpty) {
      return MovieDetailPreview.cover(url: coverUrl);
    }
    return const MovieDetailPreview.placeholder();
  }

  MovieDetailPreview _resolveUpdatedPreview(MovieDetailDto movie) {
    if (state.selectedPreview.key == 'cover') {
      final coverUrl = movie.coverImage?.bestAvailableUrl ?? '';
      if (coverUrl.isNotEmpty) {
        return MovieDetailPreview.cover(url: coverUrl);
      }
    }
    return _defaultPreviewFor(movie);
  }

  String _messageForError(Object error) {
    if (error is ApiException &&
        (error.statusCode == 404 || error.error?.code == 'movie_not_found')) {
      return '未找到该影片';
    }
    return '影片详情暂时无法加载，请稍后重试';
  }
}
