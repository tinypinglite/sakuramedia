library;

import 'package:web/web.dart' as web;

/// Web 端 PotPlayer 拉起：通过 `potplayer://` 自定义协议交给浏览器/系统处理。
bool isPotPlayerSupported() {
  final userAgent = web.window.navigator.userAgent.toLowerCase();
  return userAgent.contains('windows');
}

Future<bool> launchPotPlayerDeepLink(String url) async {
  web.window.open(url, '_self');
  return true;
}
