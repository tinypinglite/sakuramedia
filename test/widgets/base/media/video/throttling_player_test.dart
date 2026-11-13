import 'package:flutter_test/flutter_test.dart';
import 'package:media_kit/media_kit.dart';
import 'package:sakuramedia/core/media/media_source_metadata.dart';
import 'package:sakuramedia/core/media/playback_range_proxy.dart';
import 'package:sakuramedia/core/media/playback_source.dart';
import 'package:sakuramedia/core/media/playback_user_agent.dart';
import 'package:sakuramedia/widgets/base/media/video/throttling_player.dart';

import '../../../../support/test_playlist_player.dart';

void main() {
  late TestPlaylistPlayer nativePlayer;
  ThrottlingPlayer? player;

  setUp(() {
    nativePlayer = TestPlaylistPlayer();
  });

  tearDown(() async {
    await player?.dispose();
  });

  test('seek 立即执行', () async {
    player = ThrottlingPlayer(platformPlayer: nativePlayer);
    await player!.seek(const Duration(seconds: 15));

    expect(nativePlayer.calls, ['seek:15']);
  });

  test('Cloud115 打开前只应用本地代理需要的播放策略', () async {
    player = ThrottlingPlayer(
      platformPlayer: nativePlayer,
      playbackProxy: _FakePlaybackRangeProxy(),
    );
    await player!.open(
      Playlist([
        Media(
          'https://example.test/video.mp4',
          httpHeaders: const {'User-Agent': cloud115PlaybackUserAgent},
        ),
      ]),
    );

    expect(nativePlayer.properties, <String, String>{
      'cache-on-disk': 'no',
      'cache-secs': '20',
      'demuxer-max-bytes': '134217728',
      'demuxer-max-back-bytes': '67108864',
    });
    expect(nativePlayer.calls.last, 'open');
  });

  test('Cloud115 媒体打开前改写到 loopback 地址', () async {
    final proxy = _FakePlaybackRangeProxy();
    player = ThrottlingPlayer(
      platformPlayer: nativePlayer,
      playbackProxy: proxy,
    );

    await player!.open(
      Playlist([
        Media(
          'http://api.local/media/42/play/?expires=1&signature=x'
          '&playback_attempt_id=attempt',
          httpHeaders: const {'User-Agent': cloud115PlaybackUserAgent},
        ),
      ]),
    );

    final opened = nativePlayer.state.playlist.medias.single;
    expect(opened.uri, startsWith('http://127.0.0.1:1234/v?k='));
    expect(proxy.requests.single.originUrl, contains('/media/42/play/'));
    expect(
      proxy.requests.single.headers['User-Agent'],
      cloud115PlaybackUserAgent,
    );
    expect(proxy.requests.single.cacheKey, 'cloud115:api.local/media/42/play/');
    expect(
      originalMediaUriFromExtras(opened.extras),
      contains('/media/42/play/'),
    );
  });

  test('Cloud115 Playlist 保留 index、起止位置和 extras', () async {
    final proxy = _FakePlaybackRangeProxy();
    player = ThrottlingPlayer(
      platformPlayer: nativePlayer,
      playbackProxy: proxy,
    );
    final originalUrl = 'http://api.local/media/43/play/?expires=1';

    await player!.open(
      Playlist([
        Media('http://api.local/filesystem/1.mp4'),
        Media(
          originalUrl,
          extras: const <String, dynamic>{'foo': 'bar'},
          httpHeaders: const {'User-Agent': cloud115PlaybackUserAgent},
          start: const Duration(seconds: 5),
          end: const Duration(seconds: 30),
        ),
      ], index: 1),
    );

    final playlist = nativePlayer.state.playlist;
    final opened = playlist.medias[1];
    expect(playlist.index, 1);
    expect(opened.uri, startsWith('http://127.0.0.1:1234/v?k='));
    expect(opened.start, const Duration(seconds: 5));
    expect(opened.end, const Duration(seconds: 30));
    expect(opened.extras?['foo'], 'bar');
    expect(originalMediaUriFromExtras(opened.extras), originalUrl);
    expect(playlist.medias[0].uri, 'http://api.local/filesystem/1.mp4');
  });

  test('已改写的 Cloud115 媒体再次 open 不会二次代理', () async {
    final proxy = _FakePlaybackRangeProxy();
    player = ThrottlingPlayer(
      platformPlayer: nativePlayer,
      playbackProxy: proxy,
    );

    await player!.open(
      Playlist([
        Media(
          'http://api.local/media/42/play/?expires=1',
          httpHeaders: const {'User-Agent': cloud115PlaybackUserAgent},
        ),
      ]),
    );
    final firstOpenUrl = nativePlayer.state.playlist.medias.single.uri;

    await player!.open(nativePlayer.state.playlist);

    expect(nativePlayer.state.playlist.medias.single.uri, firstOpenUrl);
    expect(proxy.requests, hasLength(1));
  });

  test('Cloud115 HLS 保持原地址，避免把 m3u8 当普通文件代理', () async {
    final proxy = _FakePlaybackRangeProxy();
    player = ThrottlingPlayer(
      platformPlayer: nativePlayer,
      playbackProxy: proxy,
    );
    const originalUrl =
        'http://api.local/media/merged-play/index.m3u8'
        '?media_ids=1,2&expires=1&signature=x';

    await player!.open(
      Playlist([
        Media(
          originalUrl,
          httpHeaders: const {'User-Agent': cloud115PlaybackUserAgent},
        ),
      ]),
    );

    expect(nativePlayer.state.playlist.medias.single.uri, originalUrl);
    expect(proxy.requests, isEmpty);
  });

  test('未启用代理的 provider 和普通媒体保持原地址', () async {
    final proxy = _FakePlaybackRangeProxy();
    player = ThrottlingPlayer(
      platformPlayer: nativePlayer,
      playbackProxy: proxy,
    );
    const originalUrl = 'http://api.local/media/44/play/?expires=1';

    await player!.open(
      Playlist([
        Media(
          originalUrl,
          extras: playbackExtrasForProvider(localPlaybackProviderKey),
          httpHeaders: const {'User-Agent': defaultPlaybackUserAgent},
        ),
      ]),
    );

    expect(nativePlayer.state.playlist.medias.single.uri, originalUrl);
    expect(proxy.requests, isEmpty);
    expect(nativePlayer.properties, isEmpty);
  });

  test('同一播放器从 Cloud115 切回普通媒体时恢复 media_kit 默认缓存策略', () async {
    player = ThrottlingPlayer(
      platformPlayer: nativePlayer,
      playbackProxy: _FakePlaybackRangeProxy(),
    );
    await player!.open(
      Playlist([
        Media(
          'http://api.local/media/42/play/?expires=1',
          httpHeaders: const {'User-Agent': cloud115PlaybackUserAgent},
        ),
      ]),
    );

    await player!.open(Playlist([Media('https://example.test/reset.mp4')]));

    expect(nativePlayer.properties, <String, String>{
      'cache-on-disk': 'yes',
      'cache-secs': '3600000',
      'demuxer-max-bytes': '33554432',
      'demuxer-max-back-bytes': '33554432',
    });
  });
}

class _FakePlaybackRangeProxy implements PlaybackRangeProxy {
  final List<({String originUrl, Map<String, String> headers, String cacheKey})>
  requests = [];

  @override
  Future<Uri> localUrlFor(
    String originUrl, {
    required Map<String, String> headers,
    required String cacheKey,
  }) async {
    requests.add((originUrl: originUrl, headers: headers, cacheKey: cacheKey));
    return Uri.parse('http://127.0.0.1:1234/v?k=$cacheKey');
  }

  @override
  Future<void> dispose() async {}
}
