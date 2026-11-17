// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'clip_collections_api_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// clip_collections 域 API 的 Riverpod 入口。
///
/// 原生装配：依赖经 `ref.watch` 拉取，组合根不再 override。
/// 测试需要替身时用 `overrideWithValue(...)`。

@ProviderFor(clipCollectionsApi)
final clipCollectionsApiProvider = ClipCollectionsApiProvider._();

/// clip_collections 域 API 的 Riverpod 入口。
///
/// 原生装配：依赖经 `ref.watch` 拉取，组合根不再 override。
/// 测试需要替身时用 `overrideWithValue(...)`。

final class ClipCollectionsApiProvider
    extends
        $FunctionalProvider<
          ClipCollectionsApi,
          ClipCollectionsApi,
          ClipCollectionsApi
        >
    with $Provider<ClipCollectionsApi> {
  /// clip_collections 域 API 的 Riverpod 入口。
  ///
  /// 原生装配：依赖经 `ref.watch` 拉取，组合根不再 override。
  /// 测试需要替身时用 `overrideWithValue(...)`。
  ClipCollectionsApiProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'clipCollectionsApiProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$clipCollectionsApiHash();

  @$internal
  @override
  $ProviderElement<ClipCollectionsApi> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  ClipCollectionsApi create(Ref ref) {
    return clipCollectionsApi(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ClipCollectionsApi value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ClipCollectionsApi>(value),
    );
  }
}

String _$clipCollectionsApiHash() =>
    r'05c77987796ac9d1636618718916677ae079b520';
