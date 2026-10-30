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

  test('打开媒体前启用 FFmpeg HTTP 连接复用', () async {
    await player.open(Playlist([Media('https://example.test/video.mp4')]));

    expect(nativePlayer.properties['stream-lavf-o'], 'multiple_requests=1');
    expect(nativePlayer.calls, [
      'property:stream-lavf-o=multiple_requests=1',
      'open',
    ]);
  });
}
