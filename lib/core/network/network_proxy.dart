import 'dart:io';

import 'package:sakuramedia/core/network/debug_capture_proxy.dart';

/// 全局 HTTP 代理配置（设备级）。
class NetworkProxyConfig {
  const NetworkProxyConfig({required this.host, required this.port});

  final String host;
  final int port;

  /// 持久化 / 输入框展示用地址；IPv6 主机自动补方括号。
  String get displayAddress =>
      host.contains(':') ? '[$host]:$port' : '$host:$port';

  /// `dart:io` `HttpClient.findProxy` 指令。
  String get findProxyDirective => 'PROXY $displayAddress';

  @override
  bool operator ==(Object other) =>
      other is NetworkProxyConfig && other.host == host && other.port == port;

  @override
  int get hashCode => Object.hash(host, port);
}

/// 解析用户输入的代理地址；空输入表示未设置，返回 `null`。
///
/// 支持 `host:port`、`http://host:port` 和 `http://[::1]:7890`；只接受
/// HTTP 代理，端口必填。SOCKS5、HTTPS scheme、带路径/参数/账号密码的地址
/// 均视为非法。
NetworkProxyConfig? parseNetworkProxyAddress(String raw) {
  final value = raw.trim();
  if (value.isEmpty) {
    return null;
  }
  final normalized = value.contains('://') ? value : 'http://$value';
  final uri = Uri.tryParse(normalized);
  if (uri == null ||
      uri.scheme != 'http' ||
      uri.host.isEmpty ||
      !uri.hasPort ||
      uri.port <= 0 ||
      uri.port > 65535 ||
      uri.userInfo.isNotEmpty ||
      (uri.path.isNotEmpty && uri.path != '/') ||
      uri.hasQuery ||
      uri.hasFragment) {
    return null;
  }
  return NetworkProxyConfig(host: uri.host, port: uri.port);
}

/// 回环地址保持直连；其余目标（包括私有网段）统一走代理。
String resolveProxyDirective(Uri uri, NetworkProxyConfig? config) {
  if (config == null) {
    return 'DIRECT';
  }
  if (isLoopbackHost(uri.host)) {
    return 'DIRECT';
  }
  return config.findProxyDirective;
}

/// 目标主机是否为回环地址。
bool isLoopbackHost(String host) {
  final normalized = host.toLowerCase();
  if (normalized == 'localhost' || normalized.endsWith('.localhost')) {
    return true;
  }
  final address = InternetAddress.tryParse(normalized);
  return address?.isLoopback ?? false;
}

/// 同步网络层读取的当前代理配置。
///
/// `HttpClient.findProxy` 是同步回调，拿不到 Riverpod 容器；这里用静态可变值
/// 作为 Provider 状态到网络层的单向桥。
abstract final class NetworkProxyRuntime {
  static NetworkProxyConfig? _config;

  static NetworkProxyConfig? get config => _config;

  static void update(NetworkProxyConfig? config) {
    _config = config;
  }
}

/// 安装全局 [HttpOverrides]，让所有 Dart HTTP 客户端走用户配置的代理。
///
/// 即使当前没有配置也安装：`findProxy` 每次建连都会重新读取 runtime，这样
/// 用户保存代理后无需重启，已有 HttpClient 的新连接也会立即生效。
void installNetworkProxyOverrides(NetworkProxyConfig? initial) {
  NetworkProxyRuntime.update(initial);
  // 本地抓包开关优先，保持 debug_capture_proxy.dart 的既有行为。
  if (debugCaptureProxyActive) {
    return;
  }
  HttpOverrides.global = _NetworkProxyHttpOverrides();
}

class _NetworkProxyHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    final client = super.createHttpClient(context);
    client.findProxy = (uri) =>
        resolveProxyDirective(uri, NetworkProxyRuntime.config);
    return client;
  }
}
