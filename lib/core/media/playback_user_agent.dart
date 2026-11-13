const String defaultPlaybackUserAgent =
    'Mozilla/5.0 (Windows NT 10.0; Win64; x64) '
    'AppleWebKit/537.36 (KHTML, like Gecko) '
    'Chrome/125.0.0.0 Safari/537.36';

/// 115 官方 iOS 客户端 UA。官方 `c=0` 直链与该 UA 绑定，换 UA 会被 CDN 403。
const String cloud115PlaybackUserAgent =
    'Mozilla/5.0; Darwin/10.0; UDown/39.1.0';

String playbackUserAgentForProvider(String? providerKey) =>
    providerKey == 'cloud115'
    ? cloud115PlaybackUserAgent
    : defaultPlaybackUserAgent;

Map<String, String>? playbackHttpHeadersForProvider(String? providerKey) {
  if (providerKey != 'cloud115') {
    return null;
  }
  return const <String, String>{'User-Agent': cloud115PlaybackUserAgent};
}
