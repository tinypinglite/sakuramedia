/// PotPlayer 深链构造。
///
/// 参考 EmbyLaunchPotPlayer 的协议：
/// 1. 先把完整播放参数写进剪贴板；
/// 2. 再打开 `potplayer:///current/clipboard` 让 PotPlayer 从剪贴板读取。
library;

/// 生成交给 PotPlayer 的完整深链（会写入剪贴板）。
///
/// [streamUrl] 必须是可被 PotPlayer 直接访问的完整 URL。
/// [subtitleUrl] 可选，为空时不附加字幕参数。
/// [positionSeconds] 为续播位置（秒）。
/// [useCurrentInstance] 为 true 时附带 `/current`，让 PotPlayer 使用已打开的实例。
String buildPotPlayerDeepLink({
  required String streamUrl,
  String? subtitleUrl,
  int positionSeconds = 0,
  required String title,
  bool useCurrentInstance = true,
}) {
  final parts = <String>[
    'potplayer://${Uri.encodeFull(streamUrl)}',
    if (subtitleUrl != null && subtitleUrl.isNotEmpty)
      '/sub=${Uri.encodeFull(subtitleUrl)}',
    if (useCurrentInstance) '/current',
    '/seek=${_formatSeek(positionSeconds)}',
    '/title="${_escapeTitle(title)}"',
  ];
  return parts.join(' ');
}

/// 生成让 PotPlayer 读取剪贴板的唤起链接。
String buildPotPlayerClipboardUrl({bool useCurrentInstance = true}) {
  return useCurrentInstance
      ? 'potplayer:///current/clipboard'
      : 'potplayer:///clipboard';
}

String _formatSeek(int totalSeconds) {
  final safeSeconds = totalSeconds < 0 ? 0 : totalSeconds;
  final hours = safeSeconds ~/ 3600;
  final minutes = (safeSeconds % 3600) ~/ 60;
  final seconds = safeSeconds % 60;

  final minuteText = minutes.toString().padLeft(2, '0');
  final secondText = seconds.toString().padLeft(2, '0');
  if (hours > 0) {
    return '$hours:$minuteText:$secondText';
  }
  return '$minuteText:$secondText';
}

String _escapeTitle(String title) {
  return title.replaceAll(r'\', r'\\').replaceAll('"', r'\"');
}
