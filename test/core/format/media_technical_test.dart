import 'package:flutter_test/flutter_test.dart';
import 'package:sakuramedia/core/format/media_technical.dart';

void main() {
  test('formats video codec names', () {
    expect(formatVideoCodecName('h264'), 'H.264');
    expect(formatVideoCodecName('AVC'), 'H.264');
    expect(formatVideoCodecName('hevc'), 'H.265');
    expect(formatVideoCodecName('h265'), 'H.265');
    expect(formatVideoCodecName('mpeg4'), 'MPEG4');
    expect(formatVideoCodecName('  '), isNull);
    expect(formatVideoCodecName(null), isNull);
  });

  test('prefers video bitrate and falls back to container bitrate', () {
    expect(formatVideoBitRate(22793091, 10000000), '22.8 Mbps');
    expect(formatVideoBitRate(null, 10000000), '10.0 Mbps');
    expect(formatVideoBitRate(0, 10000000), '10.0 Mbps');
    expect(formatVideoBitRate(null, null), isNull);
    expect(formatVideoBitRate(0, 0), isNull);
  });

  test('formats integer and decimal frame rates', () {
    expect(formatVideoFrameRate(24), '24 fps');
    expect(formatVideoFrameRate(29.97), '29.97 fps');
    expect(formatVideoFrameRate(23.976), '23.98 fps');
    expect(formatVideoFrameRate(0), isNull);
    expect(formatVideoFrameRate(null), isNull);
  });
}
