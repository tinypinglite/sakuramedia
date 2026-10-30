// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'movie_summary_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// 波 A 的影片摘要分页状态。
///
/// 迁移前的七个非缓存页面各自创建 [PagedMovieSummaryController]，再手工接两个
/// ChangeNotifier 广播。这里以 [MovieSummaryScope] family 保持实例隔离，并把
/// 订阅/合集变更统一收为 `ref.listen` 的不可变本地补丁。

@ProviderFor(MovieSummary)
final movieSummaryProvider = MovieSummaryFamily._();

/// 波 A 的影片摘要分页状态。
///
/// 迁移前的七个非缓存页面各自创建 [PagedMovieSummaryController]，再手工接两个
/// ChangeNotifier 广播。这里以 [MovieSummaryScope] family 保持实例隔离，并把
/// 订阅/合集变更统一收为 `ref.listen` 的不可变本地补丁。
final class MovieSummaryProvider
    extends $AsyncNotifierProvider<MovieSummary, MovieSummaryState> {
  /// 波 A 的影片摘要分页状态。
  ///
  /// 迁移前的七个非缓存页面各自创建 [PagedMovieSummaryController]，再手工接两个
  /// ChangeNotifier 广播。这里以 [MovieSummaryScope] family 保持实例隔离，并把
  /// 订阅/合集变更统一收为 `ref.listen` 的不可变本地补丁。
  MovieSummaryProvider._({
    required MovieSummaryFamily super.from,
    required MovieSummaryScope super.argument,
  }) : super(
         retry: null,
         name: r'movieSummaryProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$movieSummaryHash();

  @override
  String toString() {
    return r'movieSummaryProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  MovieSummary create() => MovieSummary();

  @override
  bool operator ==(Object other) {
    return other is MovieSummaryProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$movieSummaryHash() => r'966f513aa86a4de1459bf083a7ad4d0b13878344';

/// 波 A 的影片摘要分页状态。
///
/// 迁移前的七个非缓存页面各自创建 [PagedMovieSummaryController]，再手工接两个
/// ChangeNotifier 广播。这里以 [MovieSummaryScope] family 保持实例隔离，并把
/// 订阅/合集变更统一收为 `ref.listen` 的不可变本地补丁。

final class MovieSummaryFamily extends $Family
    with
        $ClassFamilyOverride<
          MovieSummary,
          AsyncValue<MovieSummaryState>,
          MovieSummaryState,
          FutureOr<MovieSummaryState>,
          MovieSummaryScope
        > {
  MovieSummaryFamily._()
    : super(
        retry: null,
        name: r'movieSummaryProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// 波 A 的影片摘要分页状态。
  ///
  /// 迁移前的七个非缓存页面各自创建 [PagedMovieSummaryController]，再手工接两个
  /// ChangeNotifier 广播。这里以 [MovieSummaryScope] family 保持实例隔离，并把
  /// 订阅/合集变更统一收为 `ref.listen` 的不可变本地补丁。

  MovieSummaryProvider call(MovieSummaryScope scope) =>
      MovieSummaryProvider._(argument: scope, from: this);

  @override
  String toString() => r'movieSummaryProvider';
}

/// 波 A 的影片摘要分页状态。
///
/// 迁移前的七个非缓存页面各自创建 [PagedMovieSummaryController]，再手工接两个
/// ChangeNotifier 广播。这里以 [MovieSummaryScope] family 保持实例隔离，并把
/// 订阅/合集变更统一收为 `ref.listen` 的不可变本地补丁。

abstract class _$MovieSummary extends $AsyncNotifier<MovieSummaryState> {
  late final _$args = ref.$arg as MovieSummaryScope;
  MovieSummaryScope get scope => _$args;

  FutureOr<MovieSummaryState> build(MovieSummaryScope scope);
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref =
        this.ref as $Ref<AsyncValue<MovieSummaryState>, MovieSummaryState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<MovieSummaryState>, MovieSummaryState>,
              AsyncValue<MovieSummaryState>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, () => build(_$args));
  }
}
