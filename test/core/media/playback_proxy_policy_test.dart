import 'package:flutter_test/flutter_test.dart';
import 'package:media_kit/media_kit.dart';
import 'package:sakuramedia/core/media/playback_proxy_policy.dart';
import 'package:sakuramedia/core/media/playback_source.dart';
import 'package:sakuramedia/core/media/playback_user_agent.dart';

void main() {
  test('cloud115 opts in with one upstream slot and its default headers', () {
    final policy = playbackProxyPolicyForProvider(cloud115PlaybackProviderKey);

    expect(policy.enabled, isTrue);
    expect(policy.maxConcurrentUpstreamRequests, 1);
    expect(policy.defaultUpstreamHeaders['Referer'], 'https://115.com/');
  });

  test('local and guangyapan stay explicitly disabled', () {
    expect(
      playbackProxyPolicyForProvider(localPlaybackProviderKey).enabled,
      isFalse,
    );
    expect(
      playbackProxyPolicyForProvider(guangyapanPlaybackProviderKey).enabled,
      isFalse,
    );
    expect(playbackProxyPolicyForProvider('unknown').enabled, isFalse);
  });

  test('explicit provider extras win over user-agent inference', () {
    final media = Media(
      'https://example.test/fallback.mp4',
      extras: playbackExtrasForProvider(localPlaybackProviderKey),
      httpHeaders: const <String, String>{
        'User-Agent': cloud115PlaybackUserAgent,
      },
    );

    expect(playbackProviderKeyForMedia(media), localPlaybackProviderKey);
    expect(playbackProxyPolicyForMedia(media).enabled, isFalse);
  });

  test('cloud115 user agent remains a fallback for unmarked media', () {
    final media = Media(
      'https://example.test/video.mp4',
      httpHeaders: const <String, String>{
        'User-Agent': cloud115PlaybackUserAgent,
      },
    );

    expect(playbackProviderKeyForMedia(media), cloud115PlaybackProviderKey);
  });

  test('cache key drops volatile query values but keeps identity values', () {
    const policy = cloud115PlaybackProxyPolicy;
    final first = playbackProxyCacheKey(
      providerKey: cloud115PlaybackProviderKey,
      policy: policy,
      url:
          'https://api.test/media/42/play/?expires=1&signature=a'
          '&playback_attempt_id=one',
    );
    final second = playbackProxyCacheKey(
      providerKey: cloud115PlaybackProviderKey,
      policy: policy,
      url:
          'https://api.test/media/42/play/?expires=2&signature=b'
          '&playback_attempt_id=two',
    );
    final differentIdentity = playbackProxyCacheKey(
      providerKey: cloud115PlaybackProviderKey,
      policy: policy,
      url: 'https://api.test/media/42/play/?media_ids=1,2&expires=1',
    );

    expect(first, 'cloud115:api.test/media/42/play/');
    expect(second, first);
    expect(differentIdentity, isNot(first));
  });
}
