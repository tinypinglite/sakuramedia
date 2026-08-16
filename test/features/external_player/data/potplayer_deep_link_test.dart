import 'package:flutter_test/flutter_test.dart';
import 'package:sakuramedia/features/external_player/data/potplayer_deep_link.dart';

void main() {
  group('buildPotPlayerDeepLink', () {
    test('builds deep link with stream url, current instance, seek and title', () {
      final link = buildPotPlayerDeepLink(
        streamUrl: 'http://192.168.1.220:38000/media/1/stream?signature=abc',
        title: 'Test Movie',
        positionSeconds: 65,
      );

      expect(
        link,
        'potplayer://http://192.168.1.220:38000/media/1/stream?signature=abc '
        '/current /seek=01:05 /title="Test Movie"',
      );
    });

    test('appends subtitle url when provided', () {
      final link = buildPotPlayerDeepLink(
        streamUrl: 'http://example.com/video.mp4',
        subtitleUrl: 'http://example.com/sub.srt',
        title: 'Movie',
      );

      expect(link, contains('/sub=http://example.com/sub.srt'));
    });

    test('omits current instance when useCurrentInstance is false', () {
      final link = buildPotPlayerDeepLink(
        streamUrl: 'http://example.com/video.mp4',
        title: 'Movie',
        useCurrentInstance: false,
      );

      expect(link, isNot(contains('/current')));
      expect(link, startsWith('potplayer://http://example.com/video.mp4 '));
    });

    test('escapes quotes and backslashes in title', () {
      final link = buildPotPlayerDeepLink(
        streamUrl: 'http://example.com/video.mp4',
        title: 'A "Special" \\ Movie',
      );

      expect(link, contains(r'/title="A \"Special\" \\ Movie"'));
    });

    test('formats seek as h:mm:ss when over an hour', () {
      final link = buildPotPlayerDeepLink(
        streamUrl: 'http://example.com/video.mp4',
        title: 'Movie',
        positionSeconds: 3661,
      );

      expect(link, contains('/seek=1:01:01'));
    });
  });

  group('buildPotPlayerClipboardUrl', () {
    test('defaults to current instance clipboard url', () {
      expect(buildPotPlayerClipboardUrl(), 'potplayer:///current/clipboard');
    });

    test('can build plain clipboard url', () {
      expect(
        buildPotPlayerClipboardUrl(useCurrentInstance: false),
        'potplayer:///clipboard',
      );
    });
  });
}
