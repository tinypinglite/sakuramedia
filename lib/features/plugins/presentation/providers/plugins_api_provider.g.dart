// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'plugins_api_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// plugins 域 [PluginsApi] 的 Riverpod 入口。

@ProviderFor(pluginsApi)
final pluginsApiProvider = PluginsApiProvider._();

/// plugins 域 [PluginsApi] 的 Riverpod 入口。

final class PluginsApiProvider
    extends $FunctionalProvider<PluginsApi, PluginsApi, PluginsApi>
    with $Provider<PluginsApi> {
  /// plugins 域 [PluginsApi] 的 Riverpod 入口。
  PluginsApiProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'pluginsApiProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$pluginsApiHash();

  @$internal
  @override
  $ProviderElement<PluginsApi> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  PluginsApi create(Ref ref) {
    return pluginsApi(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(PluginsApi value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<PluginsApi>(value),
    );
  }
}

String _$pluginsApiHash() => r'8a5c827a4af65e637773d7ca1825bf83e775b4be';
