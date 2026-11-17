import 'package:flutter_test/flutter_test.dart';
import 'package:sakuramedia/features/cast/data/cast_didl.dart';

void main() {
  group('buildVideoDidl', () {
    test('生成视频条目并转义 XML 特殊字符，默认协议为 mp4', () {
      final didl = buildVideoDidl(
        url: 'http://nas.local:8000/media/1/play/?expires=1&signature=a<b>',
        title: '影片 & <特辑>',
      );

      expect(didl, contains('object.item.videoItem'));
      expect(didl, contains('http-get:*:video/mp4:*'));
      expect(didl, contains('<dc:title>影片 &amp; &lt;特辑&gt;</dc:title>'));
      expect(didl, contains('expires=1&amp;signature=a&lt;b&gt;'));
    });

    test('空标题回退为播放地址，自定义 contentType 写入 protocolInfo', () {
      final didl = buildVideoDidl(
        url: 'http://host/video.mkv',
        title: '   ',
        contentType: 'video/x-matroska',
      );

      expect(didl, contains('http-get:*:video/x-matroska:*'));
      expect(didl, contains('<dc:title>http://host/video.mkv</dc:title>'));
    });
  });
}
