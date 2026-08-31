// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'hot_reviews_api_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// hot_reviews 域 API 的 Riverpod 入口。
///
/// 原生装配：依赖经 `ref.watch` 拉取，组合根不再 override。
/// 测试需要替身时用 `overrideWithValue(...)`。

@ProviderFor(hotReviewsApi)
final hotReviewsApiProvider = HotReviewsApiProvider._();

/// hot_reviews 域 API 的 Riverpod 入口。
///
/// 原生装配：依赖经 `ref.watch` 拉取，组合根不再 override。
/// 测试需要替身时用 `overrideWithValue(...)`。

final class HotReviewsApiProvider
    extends $FunctionalProvider<HotReviewsApi, HotReviewsApi, HotReviewsApi>
    with $Provider<HotReviewsApi> {
  /// hot_reviews 域 API 的 Riverpod 入口。
  ///
  /// 原生装配：依赖经 `ref.watch` 拉取，组合根不再 override。
  /// 测试需要替身时用 `overrideWithValue(...)`。
  HotReviewsApiProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'hotReviewsApiProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$hotReviewsApiHash();

  @$internal
  @override
  $ProviderElement<HotReviewsApi> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  HotReviewsApi create(Ref ref) {
    return hotReviewsApi(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(HotReviewsApi value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<HotReviewsApi>(value),
    );
  }
}

String _$hotReviewsApiHash() => r'c84d21301f10fe80d8c81eaa34663474820bd28f';
