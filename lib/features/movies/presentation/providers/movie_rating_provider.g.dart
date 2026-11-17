// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'movie_rating_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// 单部影片的个人评分；写入/删除后就地更新状态并刷新「我的评分」列表。

@ProviderFor(MovieRating)
final movieRatingProvider = MovieRatingFamily._();

/// 单部影片的个人评分；写入/删除后就地更新状态并刷新「我的评分」列表。
final class MovieRatingProvider
    extends $AsyncNotifierProvider<MovieRating, MovieRatingDto> {
  /// 单部影片的个人评分；写入/删除后就地更新状态并刷新「我的评分」列表。
  MovieRatingProvider._({
    required MovieRatingFamily super.from,
    required String super.argument,
  }) : super(
         retry: kNoAsyncNotifierRetry,
         name: r'movieRatingProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$movieRatingHash();

  @override
  String toString() {
    return r'movieRatingProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  MovieRating create() => MovieRating();

  @override
  bool operator ==(Object other) {
    return other is MovieRatingProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$movieRatingHash() => r'64755d0dd17392e11d6e427220e34427598d6bc6';

/// 单部影片的个人评分；写入/删除后就地更新状态并刷新「我的评分」列表。

final class MovieRatingFamily extends $Family
    with
        $ClassFamilyOverride<
          MovieRating,
          AsyncValue<MovieRatingDto>,
          MovieRatingDto,
          FutureOr<MovieRatingDto>,
          String
        > {
  MovieRatingFamily._()
    : super(
        retry: kNoAsyncNotifierRetry,
        name: r'movieRatingProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// 单部影片的个人评分；写入/删除后就地更新状态并刷新「我的评分」列表。

  MovieRatingProvider call(String movieNumber) =>
      MovieRatingProvider._(argument: movieNumber, from: this);

  @override
  String toString() => r'movieRatingProvider';
}

/// 单部影片的个人评分；写入/删除后就地更新状态并刷新「我的评分」列表。

abstract class _$MovieRating extends $AsyncNotifier<MovieRatingDto> {
  late final _$args = ref.$arg as String;
  String get movieNumber => _$args;

  FutureOr<MovieRatingDto> build(String movieNumber);
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<AsyncValue<MovieRatingDto>, MovieRatingDto>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<MovieRatingDto>, MovieRatingDto>,
              AsyncValue<MovieRatingDto>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, () => build(_$args));
  }
}
