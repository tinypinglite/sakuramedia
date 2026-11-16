// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'network_proxy_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// 全局 HTTP 代理存储；生产在 `MyApp` 组合根注入 SharedPreferences 实现。

@ProviderFor(networkProxyStore)
final networkProxyStoreProvider = NetworkProxyStoreProvider._();

/// 全局 HTTP 代理存储；生产在 `MyApp` 组合根注入 SharedPreferences 实现。

final class NetworkProxyStoreProvider
    extends
        $FunctionalProvider<
          NetworkProxyStore,
          NetworkProxyStore,
          NetworkProxyStore
        >
    with $Provider<NetworkProxyStore> {
  /// 全局 HTTP 代理存储；生产在 `MyApp` 组合根注入 SharedPreferences 实现。
  NetworkProxyStoreProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'networkProxyStoreProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$networkProxyStoreHash();

  @$internal
  @override
  $ProviderElement<NetworkProxyStore> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  NetworkProxyStore create(Ref ref) {
    return networkProxyStore(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(NetworkProxyStore value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<NetworkProxyStore>(value),
    );
  }
}

String _$networkProxyStoreHash() => r'c9fb0d9f73c909e8f0522d40562a4bdaa7148027';

/// 当前全局 HTTP 代理配置，供登录页与插件页读写。

@ProviderFor(NetworkProxyController)
final networkProxyControllerProvider = NetworkProxyControllerProvider._();

/// 当前全局 HTTP 代理配置，供登录页与插件页读写。
final class NetworkProxyControllerProvider
    extends $NotifierProvider<NetworkProxyController, NetworkProxyConfig?> {
  /// 当前全局 HTTP 代理配置，供登录页与插件页读写。
  NetworkProxyControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'networkProxyControllerProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$networkProxyControllerHash();

  @$internal
  @override
  NetworkProxyController create() => NetworkProxyController();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(NetworkProxyConfig? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<NetworkProxyConfig?>(value),
    );
  }
}

String _$networkProxyControllerHash() =>
    r'dfbbe3a43bd1a3bdd95f150a14d01c721b5d7b44';

/// 当前全局 HTTP 代理配置，供登录页与插件页读写。

abstract class _$NetworkProxyController extends $Notifier<NetworkProxyConfig?> {
  NetworkProxyConfig? build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<NetworkProxyConfig?, NetworkProxyConfig?>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<NetworkProxyConfig?, NetworkProxyConfig?>,
              NetworkProxyConfig?,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
