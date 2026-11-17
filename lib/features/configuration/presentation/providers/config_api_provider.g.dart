// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'config_api_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// configuration 域 ConfigApi 的 Riverpod 入口。
///
/// 原生装配：依赖经 `ref.watch` 拉取，组合根不再 override。
/// 测试需要替身时用 `overrideWithValue(...)`。

@ProviderFor(configApi)
final configApiProvider = ConfigApiProvider._();

/// configuration 域 ConfigApi 的 Riverpod 入口。
///
/// 原生装配：依赖经 `ref.watch` 拉取，组合根不再 override。
/// 测试需要替身时用 `overrideWithValue(...)`。

final class ConfigApiProvider
    extends $FunctionalProvider<ConfigApi, ConfigApi, ConfigApi>
    with $Provider<ConfigApi> {
  /// configuration 域 ConfigApi 的 Riverpod 入口。
  ///
  /// 原生装配：依赖经 `ref.watch` 拉取，组合根不再 override。
  /// 测试需要替身时用 `overrideWithValue(...)`。
  ConfigApiProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'configApiProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$configApiHash();

  @$internal
  @override
  $ProviderElement<ConfigApi> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  ConfigApi create(Ref ref) {
    return configApi(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ConfigApi value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ConfigApi>(value),
    );
  }
}

String _$configApiHash() => r'254d46af7ff8a566249bbaf520a1dceb678b53c3';
