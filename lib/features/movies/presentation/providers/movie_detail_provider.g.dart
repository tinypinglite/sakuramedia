// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'movie_detail_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
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

@ProviderFor(MovieDetail)
final movieDetailProvider = MovieDetailFamily._();

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
final class MovieDetailProvider
    extends $NotifierProvider<MovieDetail, MovieDetailState> {
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
  MovieDetailProvider._({
    required MovieDetailFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'movieDetailProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$movieDetailHash();

  @override
  String toString() {
    return r'movieDetailProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  MovieDetail create() => MovieDetail();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(MovieDetailState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<MovieDetailState>(value),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is MovieDetailProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$movieDetailHash() => r'66c8f8a525d23c16858e46998e3713f571b300d9';

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

final class MovieDetailFamily extends $Family
    with
        $ClassFamilyOverride<
          MovieDetail,
          MovieDetailState,
          MovieDetailState,
          MovieDetailState,
          String
        > {
  MovieDetailFamily._()
    : super(
        retry: null,
        name: r'movieDetailProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

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

  MovieDetailProvider call(String movieNumber) =>
      MovieDetailProvider._(argument: movieNumber, from: this);

  @override
  String toString() => r'movieDetailProvider';
}

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

abstract class _$MovieDetail extends $Notifier<MovieDetailState> {
  late final _$args = ref.$arg as String;
  String get movieNumber => _$args;

  MovieDetailState build(String movieNumber);
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<MovieDetailState, MovieDetailState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<MovieDetailState, MovieDetailState>,
              MovieDetailState,
              Object?,
              Object?
            >;
    element.handleCreate(ref, () => build(_$args));
  }
}
