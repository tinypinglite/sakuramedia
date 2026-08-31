// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'movie_detail_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// 影片详情 provider —— autoDispose family (movieNumber) + `cacheLink` 挂
/// [RiverpodPageCache]，跨导航保活。迁移前对应 `MovieDetailController`
/// (`ChangeNotifier` + `DisposeSafeNotifier`，双端 detail 页 initState new 出)。
///
/// 语义等价旧 controller：
/// - `load()` 首次进入：`isLoading=true` + 清 similar/error，并行拉 detail /
///   storageDescriptors + 相似影片。失败置 `errorMessage`，movie/storage 归空。
/// - `refresh()`：**不置** `isLoading` (统计条不闪骨架)，并行重拉后原地写。
///   相似影片仍先置 `isSimilarMoviesLoading` 再写。
/// - `applyMovie(movie, resetPreview)`：外部（如详情动作 refreshMetadata）
///   拿到新 DTO 后就地写入 + 决策预览是否重置。
/// - `retryLoadSimilarMovies()`：仅重拉相似影片，不清列表。

@ProviderFor(MovieDetail)
final movieDetailProvider = MovieDetailFamily._();

/// 影片详情 provider —— autoDispose family (movieNumber) + `cacheLink` 挂
/// [RiverpodPageCache]，跨导航保活。迁移前对应 `MovieDetailController`
/// (`ChangeNotifier` + `DisposeSafeNotifier`，双端 detail 页 initState new 出)。
///
/// 语义等价旧 controller：
/// - `load()` 首次进入：`isLoading=true` + 清 similar/error，并行拉 detail /
///   storageDescriptors + 相似影片。失败置 `errorMessage`，movie/storage 归空。
/// - `refresh()`：**不置** `isLoading` (统计条不闪骨架)，并行重拉后原地写。
///   相似影片仍先置 `isSimilarMoviesLoading` 再写。
/// - `applyMovie(movie, resetPreview)`：外部（如详情动作 refreshMetadata）
///   拿到新 DTO 后就地写入 + 决策预览是否重置。
/// - `retryLoadSimilarMovies()`：仅重拉相似影片，不清列表。
final class MovieDetailProvider
    extends $NotifierProvider<MovieDetail, MovieDetailState> {
  /// 影片详情 provider —— autoDispose family (movieNumber) + `cacheLink` 挂
  /// [RiverpodPageCache]，跨导航保活。迁移前对应 `MovieDetailController`
  /// (`ChangeNotifier` + `DisposeSafeNotifier`，双端 detail 页 initState new 出)。
  ///
  /// 语义等价旧 controller：
  /// - `load()` 首次进入：`isLoading=true` + 清 similar/error，并行拉 detail /
  ///   storageDescriptors + 相似影片。失败置 `errorMessage`，movie/storage 归空。
  /// - `refresh()`：**不置** `isLoading` (统计条不闪骨架)，并行重拉后原地写。
  ///   相似影片仍先置 `isSimilarMoviesLoading` 再写。
  /// - `applyMovie(movie, resetPreview)`：外部（如详情动作 refreshMetadata）
  ///   拿到新 DTO 后就地写入 + 决策预览是否重置。
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

String _$movieDetailHash() => r'4019398edede627e1362d0b9dd927d786b62f99d';

/// 影片详情 provider —— autoDispose family (movieNumber) + `cacheLink` 挂
/// [RiverpodPageCache]，跨导航保活。迁移前对应 `MovieDetailController`
/// (`ChangeNotifier` + `DisposeSafeNotifier`，双端 detail 页 initState new 出)。
///
/// 语义等价旧 controller：
/// - `load()` 首次进入：`isLoading=true` + 清 similar/error，并行拉 detail /
///   storageDescriptors + 相似影片。失败置 `errorMessage`，movie/storage 归空。
/// - `refresh()`：**不置** `isLoading` (统计条不闪骨架)，并行重拉后原地写。
///   相似影片仍先置 `isSimilarMoviesLoading` 再写。
/// - `applyMovie(movie, resetPreview)`：外部（如详情动作 refreshMetadata）
///   拿到新 DTO 后就地写入 + 决策预览是否重置。
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
  /// [RiverpodPageCache]，跨导航保活。迁移前对应 `MovieDetailController`
  /// (`ChangeNotifier` + `DisposeSafeNotifier`，双端 detail 页 initState new 出)。
  ///
  /// 语义等价旧 controller：
  /// - `load()` 首次进入：`isLoading=true` + 清 similar/error，并行拉 detail /
  ///   storageDescriptors + 相似影片。失败置 `errorMessage`，movie/storage 归空。
  /// - `refresh()`：**不置** `isLoading` (统计条不闪骨架)，并行重拉后原地写。
  ///   相似影片仍先置 `isSimilarMoviesLoading` 再写。
  /// - `applyMovie(movie, resetPreview)`：外部（如详情动作 refreshMetadata）
  ///   拿到新 DTO 后就地写入 + 决策预览是否重置。
  /// - `retryLoadSimilarMovies()`：仅重拉相似影片，不清列表。

  MovieDetailProvider call(String movieNumber) =>
      MovieDetailProvider._(argument: movieNumber, from: this);

  @override
  String toString() => r'movieDetailProvider';
}

/// 影片详情 provider —— autoDispose family (movieNumber) + `cacheLink` 挂
/// [RiverpodPageCache]，跨导航保活。迁移前对应 `MovieDetailController`
/// (`ChangeNotifier` + `DisposeSafeNotifier`，双端 detail 页 initState new 出)。
///
/// 语义等价旧 controller：
/// - `load()` 首次进入：`isLoading=true` + 清 similar/error，并行拉 detail /
///   storageDescriptors + 相似影片。失败置 `errorMessage`，movie/storage 归空。
/// - `refresh()`：**不置** `isLoading` (统计条不闪骨架)，并行重拉后原地写。
///   相似影片仍先置 `isSimilarMoviesLoading` 再写。
/// - `applyMovie(movie, resetPreview)`：外部（如详情动作 refreshMetadata）
///   拿到新 DTO 后就地写入 + 决策预览是否重置。
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
