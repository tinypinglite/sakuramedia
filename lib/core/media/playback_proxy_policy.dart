import 'package:media_kit/media_kit.dart';
import 'package:sakuramedia/core/media/playback_source.dart';
import 'package:sakuramedia/core/media/playback_user_agent.dart';

/// Transport policy for the loopback byte-range proxy.
///
/// Providers opt in when their playback endpoint needs the proxy's transport
/// behavior, or when the client should observe range traffic for playback
/// diagnostics such as A/V interleaving detection.
class PlaybackProxyPolicy {
  const PlaybackProxyPolicy({
    required this.providerKey,
    required this.enabled,
    this.maxConcurrentUpstreamRequests = 1,
    this.upstreamWindowBytes = 128 * 1024 * 1024,
    this.upstreamTimeout = const Duration(seconds: 30),
    this.downstreamFlushTimeout = const Duration(minutes: 5),
    this.retryDelay = const Duration(milliseconds: 400),
    this.maxAttempts = 3,
    this.cooldown = const Duration(milliseconds: 20),
    this.keepAlive = true,
    this.idleConnectionTimeout = const Duration(seconds: 1),
    this.defaultUpstreamHeaders = const <String, String>{},
    this.volatileQueryKeys = const <String>{},
  }) : assert(maxConcurrentUpstreamRequests > 0),
       assert(upstreamWindowBytes > 0),
       assert(maxAttempts > 0);

  const PlaybackProxyPolicy.disabled(this.providerKey)
    : enabled = false,
      maxConcurrentUpstreamRequests = 1,
      upstreamWindowBytes = 1,
      upstreamTimeout = const Duration(seconds: 30),
      downstreamFlushTimeout = const Duration(minutes: 5),
      retryDelay = Duration.zero,
      maxAttempts = 1,
      cooldown = Duration.zero,
      keepAlive = false,
      idleConnectionTimeout = Duration.zero,
      defaultUpstreamHeaders = const <String, String>{},
      volatileQueryKeys = const <String>{};

  final String providerKey;
  final bool enabled;

  /// 同一条播放链接允许的同时上游请求数。
  ///
  /// 不同播放链接各自持有独立的闸门，不会互相排队；115 的并发限制本来就是
  /// 按链接下发的（不同链接上限不同）。
  final int maxConcurrentUpstreamRequests;
  final int upstreamWindowBytes;
  final Duration upstreamTimeout;
  final Duration downstreamFlushTimeout;
  final Duration retryDelay;
  final int maxAttempts;
  final Duration cooldown;
  final bool keepAlive;
  final Duration idleConnectionTimeout;
  final Map<String, String> defaultUpstreamHeaders;
  final Set<String> volatileQueryKeys;

  PlaybackProxyPolicy copyWith({
    bool? enabled,
    int? maxConcurrentUpstreamRequests,
    int? upstreamWindowBytes,
    Duration? upstreamTimeout,
    Duration? downstreamFlushTimeout,
    Duration? retryDelay,
    int? maxAttempts,
    Duration? cooldown,
    bool? keepAlive,
    Duration? idleConnectionTimeout,
    Map<String, String>? defaultUpstreamHeaders,
    Set<String>? volatileQueryKeys,
  }) => PlaybackProxyPolicy(
    providerKey: providerKey,
    enabled: enabled ?? this.enabled,
    maxConcurrentUpstreamRequests:
        maxConcurrentUpstreamRequests ?? this.maxConcurrentUpstreamRequests,
    upstreamWindowBytes: upstreamWindowBytes ?? this.upstreamWindowBytes,
    upstreamTimeout: upstreamTimeout ?? this.upstreamTimeout,
    downstreamFlushTimeout:
        downstreamFlushTimeout ?? this.downstreamFlushTimeout,
    retryDelay: retryDelay ?? this.retryDelay,
    maxAttempts: maxAttempts ?? this.maxAttempts,
    cooldown: cooldown ?? this.cooldown,
    keepAlive: keepAlive ?? this.keepAlive,
    idleConnectionTimeout: idleConnectionTimeout ?? this.idleConnectionTimeout,
    defaultUpstreamHeaders:
        defaultUpstreamHeaders ?? this.defaultUpstreamHeaders,
    volatileQueryKeys: volatileQueryKeys ?? this.volatileQueryKeys,
  );
}

const Set<String> _signedPlaybackVolatileQueryKeys = <String>{
  'expires',
  'signature',
  'playback_attempt_id',
  'delivery',
};

const PlaybackProxyPolicy cloud115PlaybackProxyPolicy = PlaybackProxyPolicy(
  providerKey: cloud115PlaybackProviderKey,
  enabled: true,
  maxConcurrentUpstreamRequests: 1,
  defaultUpstreamHeaders: <String, String>{'Referer': 'https://115.com/'},
  volatileQueryKeys: <String>{
    'expires',
    'signature',
    'sig',
    'token',
    'playback_attempt_id',
    'delivery',
    't',
    'u',
    's',
    'd',
    'c',
    'f',
    'k',
    'us',
    'uc',
    'v',
  },
);

/// 本地库由后端以 signed URL 读文件；套一层 loopback 代理用于统一缓冲策略
/// 和音视频交错检测。
const PlaybackProxyPolicy localPlaybackProxyPolicy = PlaybackProxyPolicy(
  providerKey: localPlaybackProviderKey,
  enabled: true,
  defaultUpstreamHeaders: <String, String>{
    'User-Agent': defaultPlaybackUserAgent,
  },
  volatileQueryKeys: _signedPlaybackVolatileQueryKeys,
);

/// 光鸭播放地址先指向后端 signed URL，再由后端 302 到 CDN；直链支持 Range，
/// 可以用同一个 loopback 代理做检测。
const PlaybackProxyPolicy guangyapanPlaybackProxyPolicy = PlaybackProxyPolicy(
  providerKey: guangyapanPlaybackProviderKey,
  enabled: true,
  defaultUpstreamHeaders: <String, String>{
    'User-Agent': defaultPlaybackUserAgent,
  },
  volatileQueryKeys: _signedPlaybackVolatileQueryKeys,
);

const PlaybackProxyPolicy _disabledPlaybackProxyPolicy =
    PlaybackProxyPolicy.disabled('');

PlaybackProxyPolicy playbackProxyPolicyForProvider(String? providerKey) =>
    switch (providerKey?.trim()) {
      cloud115PlaybackProviderKey => cloud115PlaybackProxyPolicy,
      localPlaybackProviderKey => localPlaybackProxyPolicy,
      guangyapanPlaybackProviderKey => guangyapanPlaybackProxyPolicy,
      _ => _disabledPlaybackProxyPolicy,
    };

String? playbackProviderKeyForMedia(Media media) {
  final explicit = playbackProviderKeyFromExtras(media.extras);
  if (explicit != null) {
    return explicit;
  }
  final userAgent = _headerValue(media.httpHeaders, 'user-agent');
  return userAgent == cloud115PlaybackUserAgent
      ? cloud115PlaybackProviderKey
      : null;
}

PlaybackProxyPolicy playbackProxyPolicyForMedia(Media media) =>
    playbackProxyPolicyForProvider(playbackProviderKeyForMedia(media));

String playbackProxyCacheKey({
  required String providerKey,
  required PlaybackProxyPolicy policy,
  required String url,
}) {
  final uri = Uri.tryParse(url);
  if (uri == null) {
    return '$providerKey:$url';
  }
  final stableQuery = <String>[];
  final queryKeys = uri.queryParametersAll.keys.toList()..sort();
  for (final key in queryKeys) {
    if (policy.volatileQueryKeys.contains(key.toLowerCase())) {
      continue;
    }
    final values = uri.queryParametersAll[key]!.toList()..sort();
    for (final value in values) {
      stableQuery.add(
        '${Uri.encodeQueryComponent(key)}=${Uri.encodeQueryComponent(value)}',
      );
    }
  }
  final suffix = stableQuery.isEmpty ? '' : '?${stableQuery.join('&')}';
  return '$providerKey:${uri.host}${uri.path}$suffix';
}

String? _headerValue(Map<String, String>? headers, String name) {
  if (headers == null) {
    return null;
  }
  final target = name.toLowerCase();
  for (final entry in headers.entries) {
    if (entry.key.toLowerCase() == target) {
      return entry.value;
    }
  }
  return null;
}
