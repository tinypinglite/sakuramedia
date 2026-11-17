import 'package:flutter_test/flutter_test.dart';
import 'package:sakuramedia/core/media/playback_user_agent.dart';

void main() {
  test('cloud115 uses the official iOS app user agent', () {
    expect(playbackUserAgentForProvider('cloud115'), cloud115PlaybackUserAgent);
    expect(playbackHttpHeadersForProvider('cloud115'), <String, String>{
      'User-Agent': cloud115PlaybackUserAgent,
    });
  });

  test('other providers keep the existing playback headers', () {
    expect(
      playbackUserAgentForProvider('filesystem'),
      defaultPlaybackUserAgent,
    );
    expect(playbackHttpHeadersForProvider('filesystem'), isNull);
    expect(playbackHttpHeadersForProvider(null), isNull);
  });
}
