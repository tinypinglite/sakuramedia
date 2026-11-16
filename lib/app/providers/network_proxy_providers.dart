import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:sakuramedia/app/network_proxy_store.dart';
import 'package:sakuramedia/core/network/network_proxy.dart';

part 'network_proxy_providers.g.dart';

/// 全局 HTTP 代理存储；生产在 `MyApp` 组合根注入 SharedPreferences 实现。
@Riverpod(keepAlive: true)
NetworkProxyStore networkProxyStore(Ref ref) => InMemoryNetworkProxyStore();

/// 当前全局 HTTP 代理配置，供登录页与插件页读写。
@Riverpod(keepAlive: true)
class NetworkProxyController extends _$NetworkProxyController {
  @override
  NetworkProxyConfig? build() {
    final config = ref.watch(networkProxyStoreProvider).read();
    // findProxy 是同步回调，拿不到容器；这里把 Provider 状态镜像给网络层。
    NetworkProxyRuntime.update(config);
    return config;
  }

  Future<void> save(NetworkProxyConfig config) async {
    if (state == config) {
      return;
    }
    state = config;
    NetworkProxyRuntime.update(config);
    await ref.read(networkProxyStoreProvider).save(config);
  }

  Future<void> clear() async {
    if (state == null) {
      return;
    }
    state = null;
    NetworkProxyRuntime.update(null);
    await ref.read(networkProxyStoreProvider).save(null);
  }
}
