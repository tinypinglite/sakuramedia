// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'rating_dimensions_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// 全局评分维度；维度变更会影响所有影片的总分，写入后重拉并失效已评分列表。

@ProviderFor(RatingDimensions)
final ratingDimensionsProvider = RatingDimensionsProvider._();

/// 全局评分维度；维度变更会影响所有影片的总分，写入后重拉并失效已评分列表。
final class RatingDimensionsProvider
    extends $AsyncNotifierProvider<RatingDimensions, List<RatingDimensionDto>> {
  /// 全局评分维度；维度变更会影响所有影片的总分，写入后重拉并失效已评分列表。
  RatingDimensionsProvider._()
    : super(
        from: null,
        argument: null,
        retry: kNoAsyncNotifierRetry,
        name: r'ratingDimensionsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$ratingDimensionsHash();

  @$internal
  @override
  RatingDimensions create() => RatingDimensions();
}

String _$ratingDimensionsHash() => r'8b8d061f8d1722960e4b1141de468c2859148811';

/// 全局评分维度；维度变更会影响所有影片的总分，写入后重拉并失效已评分列表。

abstract class _$RatingDimensions
    extends $AsyncNotifier<List<RatingDimensionDto>> {
  FutureOr<List<RatingDimensionDto>> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref =
        this.ref
            as $Ref<
              AsyncValue<List<RatingDimensionDto>>,
              List<RatingDimensionDto>
            >;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<
                AsyncValue<List<RatingDimensionDto>>,
                List<RatingDimensionDto>
              >,
              AsyncValue<List<RatingDimensionDto>>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
