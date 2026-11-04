import 'package:flutter_test/flutter_test.dart';
import 'package:sakuramedia/features/media/data/media_technical_info_dto.dart';

void main() {
  test('parses the list technical fields from video_info', () {
    final info = MediaTechnicalInfoDto.fromVideoInfoJson(<String, dynamic>{
      'container': <String, dynamic>{'bit_rate': 10000000},
      'video': <String, dynamic>{
        'codec_name': 'hevc',
        'bit_rate': '9000000',
        'frame_rate': 29.97,
      },
    });

    expect(info.codecName, 'hevc');
    expect(info.videoBitRate, 9000000);
    expect(info.containerBitRate, 10000000);
    expect(info.frameRate, 29.97);
  });

  test('tolerates missing or malformed video_info fields', () {
    final info = MediaTechnicalInfoDto.fromVideoInfoJson(<String, dynamic>{
      'video': <String, dynamic>{
        'codec_name': '  ',
        'bit_rate': 'invalid',
        'frame_rate': null,
      },
    });

    expect(info.codecName, isNull);
    expect(info.videoBitRate, isNull);
    expect(info.containerBitRate, isNull);
    expect(info.frameRate, isNull);
  });
}
