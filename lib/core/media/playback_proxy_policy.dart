import 'package:media_kit/media_kit.dart';
import 'package:sakuramedia/core/media/playback_source.dart';
import 'package:sakuramedia/core/media/playback_user_agent.dart';

/// Transport policy for the loopback byte-range proxy.
///
/// Being able to proxy every source does not mean every source should be
/// proxied. Providers opt in only when their playback endpoint needs the
/// proxy's concurrency or header behavior.
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

const PlaybackProxyPolicy _disabledPlaybackProxyPolicy =
    PlaybackProxyPolicy.disabled('');

PlaybackProxyPolicy playbackProxyPolicyForProvider(String? providerKey) =>
    switch (providerKey?.trim()) {
      cloud115PlaybackProviderKey => cloud115PlaybackProxyPolicy,
      localPlaybackProviderKey => const PlaybackProxyPolicy.disabled(
        localPlaybackProviderKey,
      ),
      guangyapanPlaybackProviderKey => const PlaybackProxyPolicy.disabled(
        guangyapanPlaybackProviderKey,
      ),
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
