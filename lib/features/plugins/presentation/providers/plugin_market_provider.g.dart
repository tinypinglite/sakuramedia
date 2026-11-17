// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'plugin_market_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// 插件市场索引与市场安装 / 更新操作的会话级共享状态。

@ProviderFor(PluginMarket)
final pluginMarketProvider = PluginMarketProvider._();

/// 插件市场索引与市场安装 / 更新操作的会话级共享状态。
final class PluginMarketProvider
    extends $AsyncNotifierProvider<PluginMarket, PluginMarketState> {
  /// 插件市场索引与市场安装 / 更新操作的会话级共享状态。
  PluginMarketProvider._()
    : super(
        from: null,
        argument: null,
        retry: kNoAsyncNotifierRetry,
        name: r'pluginMarketProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$pluginMarketHash();

  @$internal
  @override
  PluginMarket create() => PluginMarket();
}

String _$pluginMarketHash() => r'904e68daeff3272ff2e683041ebea3b79aeab35a';

/// 插件市场索引与市场安装 / 更新操作的会话级共享状态。

abstract class _$PluginMarket extends $AsyncNotifier<PluginMarketState> {
  FutureOr<PluginMarketState> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref =
        this.ref as $Ref<AsyncValue<PluginMarketState>, PluginMarketState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<PluginMarketState>, PluginMarketState>,
              AsyncValue<PluginMarketState>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
