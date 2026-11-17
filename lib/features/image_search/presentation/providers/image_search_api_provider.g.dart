// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'image_search_api_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// image_search 域 API 的 Riverpod 入口。
///
/// 原生装配：依赖经 `ref.watch` 拉取，组合根不再 override。
/// 测试需要替身时用 `overrideWithValue(...)`。

@ProviderFor(imageSearchApi)
final imageSearchApiProvider = ImageSearchApiProvider._();

/// image_search 域 API 的 Riverpod 入口。
///
/// 原生装配：依赖经 `ref.watch` 拉取，组合根不再 override。
/// 测试需要替身时用 `overrideWithValue(...)`。

final class ImageSearchApiProvider
    extends $FunctionalProvider<ImageSearchApi, ImageSearchApi, ImageSearchApi>
    with $Provider<ImageSearchApi> {
  /// image_search 域 API 的 Riverpod 入口。
  ///
  /// 原生装配：依赖经 `ref.watch` 拉取，组合根不再 override。
  /// 测试需要替身时用 `overrideWithValue(...)`。
  ImageSearchApiProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'imageSearchApiProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$imageSearchApiHash();

  @$internal
  @override
  $ProviderElement<ImageSearchApi> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  ImageSearchApi create(Ref ref) {
    return imageSearchApi(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ImageSearchApi value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ImageSearchApi>(value),
    );
  }
}

String _$imageSearchApiHash() => r'5c161c69177643f3967ea452f376e6f6102c178f';
