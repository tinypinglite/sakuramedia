// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'discovery_api_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// discovery 域 API 的 Riverpod 入口。
///
/// 原生装配：依赖经 `ref.watch` 拉取，组合根不再 override。
/// 测试需要替身时用 `overrideWithValue(...)`。

@ProviderFor(discoveryApi)
final discoveryApiProvider = DiscoveryApiProvider._();

/// discovery 域 API 的 Riverpod 入口。
///
/// 原生装配：依赖经 `ref.watch` 拉取，组合根不再 override。
/// 测试需要替身时用 `overrideWithValue(...)`。

final class DiscoveryApiProvider
    extends $FunctionalProvider<DiscoveryApi, DiscoveryApi, DiscoveryApi>
    with $Provider<DiscoveryApi> {
  /// discovery 域 API 的 Riverpod 入口。
  ///
  /// 原生装配：依赖经 `ref.watch` 拉取，组合根不再 override。
  /// 测试需要替身时用 `overrideWithValue(...)`。
  DiscoveryApiProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'discoveryApiProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$discoveryApiHash();

  @$internal
  @override
  $ProviderElement<DiscoveryApi> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  DiscoveryApi create(Ref ref) {
    return discoveryApi(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(DiscoveryApi value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<DiscoveryApi>(value),
    );
  }
}

String _$discoveryApiHash() => r'e9d76186fa7039393fb9b6939cff3519ae54ca3c';
