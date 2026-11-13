import 'dart:io';

import 'package:flutter/foundation.dart';

/// 本地抓包临时开关。默认关闭，只有显式传入以下 dart-define 才生效：
///
/// ```text
/// --dart-define=SAKURAMEDIA_CAPTURE_PROXY_ENABLED=true
/// ```
///
/// 代理地址默认是 `http://127.0.0.1:8888`，真机抓包可额外传入：
///
/// ```text
/// --dart-define=SAKURAMEDIA_CAPTURE_PROXY=http://<Mac局域网IP>:8888
/// ```
const bool _captureProxyEnabled = bool.fromEnvironment(
  'SAKURAMEDIA_CAPTURE_PROXY_ENABLED',
  defaultValue: false,
);

const String _captureProxyUrl = String.fromEnvironment(
  'SAKURAMEDIA_CAPTURE_PROXY',
  defaultValue: 'http://127.0.0.1:8888',
);

bool get debugCaptureProxyActive {
  if (!kDebugMode || !_captureProxyEnabled) {
    return false;
  }
  final uri = Uri.tryParse(_captureProxyUrl);
  return uri != null && uri.host.isNotEmpty && uri.port > 0;
}

String get debugCaptureProxyUrl => _captureProxyUrl;

/// 追加到 `stream-lavf-o` 的抓包代理选项；未开启代理时为空。
///
/// 生产侧的 HTTP 连接策略由 `ThrottlingPlayer` 统一设置，不放在这里。
String get debugCaptureStreamLavfProxyOptions {
  if (!debugCaptureProxyActive) {
    return '';
  }
  return ',http_proxy=$_captureProxyUrl';
}

/// 让 Dio、NetworkImage、cached_network_image 等 Dart HTTP 客户端统一走代理。
///
/// 回环地址保持直连，避免把 VM Service/调试通道也送进代理。
void installDebugCaptureHttpProxy() {
  if (!debugCaptureProxyActive) {
    return;
  }
  HttpOverrides.global = _CaptureHttpOverrides();
  debugPrint('[capture-proxy] dart-http -> $_captureProxyUrl');
}

class _CaptureHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    final client = super.createHttpClient(context);
    final proxy = Uri.parse(_captureProxyUrl);
    client.findProxy = (uri) {
      if (_isLoopback(uri.host)) {
        return 'DIRECT';
      }
      return 'PROXY ${proxy.host}:${proxy.port}';
    };
    // 仅用于本地 Charles 抓包；关闭开关后不会安装这个覆盖。
    client.badCertificateCallback = (_, _, _) => true;
    return client;
  }

  static bool _isLoopback(String host) {
    return host == '127.0.0.1' || host == 'localhost' || host == '::1';
  }
}
