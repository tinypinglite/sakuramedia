import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

/// 用系统浏览器打开外部链接；测试通过 override 注入假实现。
typedef ExternalUrlOpener = Future<bool> Function(Uri uri);

final externalUrlOpenerProvider = Provider<ExternalUrlOpener>((ref) {
  return (uri) async {
    try {
      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      return false;
    }
  };
});
