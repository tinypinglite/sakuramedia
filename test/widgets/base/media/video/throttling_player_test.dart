import 'package:flutter_test/flutter_test.dart';
import 'package:media_kit/media_kit.dart';
import 'package:sakuramedia/widgets/base/media/video/throttling_player.dart';

import '../../../../support/test_playlist_player.dart';

void main() {
  late TestPlaylistPlayer nativePlayer;
  late ThrottlingPlayer player;

  setUp(() {
    nativePlayer = TestPlaylistPlayer();
    player = ThrottlingPlayer(platformPlayer: nativePlayer);
  });

  tearDown(() async {
    await player.dispose();
  });

  test('seek 立即执行', () async {
    await player.seek(const Duration(seconds: 15));

    expect(nativePlayer.calls, ['seek:15']);
  });

  test('打开媒体前应用统一的网络读取策略', () async {
    await player.open(Playlist([Media('https://example.test/video.mp4')]));

    expect(nativePlayer.properties, <String, String>{
      'cache': 'yes',
      'cache-on-disk': 'no',
      'cache-secs': '4',
      'demuxer-readahead-secs': '4',
      'stream-lavf-o': 'multiple_requests=0',
    });
    expect(nativePlayer.calls.last, 'open');
  });
}
