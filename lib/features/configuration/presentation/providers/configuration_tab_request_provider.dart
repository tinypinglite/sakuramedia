import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 「去修复」等入口请求配置页选中某个分类的一次性信号。
///
/// 配置页是主路由分支里的常驻页面，普通跳转不会重建它；用这个信号让它在收到
/// 请求时切换分类，并在应用后立即清空，避免后续进入配置页时被旧请求带偏。
class ConfigurationTabRequest extends Notifier<String?> {
  @override
  String? build() => null;

  void request(String tabKey) => state = tabKey;

  void clear() {
    if (state != null) {
      state = null;
    }
  }
}

final configurationTabRequestProvider =
    NotifierProvider<ConfigurationTabRequest, String?>(
      ConfigurationTabRequest.new,
    );
