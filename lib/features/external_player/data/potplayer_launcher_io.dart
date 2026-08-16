import 'dart:io';

/// 桌面端 PotPlayer 拉起。
///
/// PotPlayer 是 Windows 专用，macOS/Linux 不展示入口；这里仍保留通用 open
/// 命令，方便未来接入其它自定义协议播放器。
library;

bool isPotPlayerSupported() => Platform.isWindows;

Future<bool> launchPotPlayerDeepLink(String url) async {
  try {
    if (Platform.isWindows) {
      await Process.run('cmd', <String>['/c', 'start', '', url]);
    } else if (Platform.isMacOS) {
      await Process.run('open', <String>[url]);
    } else {
      await Process.run('xdg-open', <String>[url]);
    }
    return true;
  } catch (_) {
    return false;
  }
}
