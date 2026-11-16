import 'package:shared_preferences/shared_preferences.dart';
import 'package:sakuramedia/core/network/network_proxy.dart';

/// 全局 HTTP 代理存储；设备级，不跟账号。
abstract class NetworkProxyStore {
  NetworkProxyConfig? read();
  Future<void> save(NetworkProxyConfig? config);
}

class SharedPreferencesNetworkProxyStore implements NetworkProxyStore {
  SharedPreferencesNetworkProxyStore(this._preferences);

  static const String proxyKey = 'network.proxy';

  final SharedPreferences _preferences;

  static Future<NetworkProxyStore> create() async {
    final preferences = await SharedPreferences.getInstance();
    return SharedPreferencesNetworkProxyStore(preferences);
  }

  @override
  NetworkProxyConfig? read() {
    return parseNetworkProxyAddress(_preferences.getString(proxyKey) ?? '');
  }

  @override
  Future<void> save(NetworkProxyConfig? config) async {
    try {
      if (config == null) {
        await _preferences.remove(proxyKey);
      } else {
        await _preferences.setString(proxyKey, config.displayAddress);
      }
    } catch (_) {
      // 持久化失败不阻塞本次生效；下次启动回退到上次保存的值。
    }
  }
}

class InMemoryNetworkProxyStore implements NetworkProxyStore {
  InMemoryNetworkProxyStore([this._config]);

  NetworkProxyConfig? _config;

  @override
  NetworkProxyConfig? read() => _config;

  @override
  Future<void> save(NetworkProxyConfig? config) async {
    _config = config;
  }
}
