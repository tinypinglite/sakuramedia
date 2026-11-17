import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:sakuramedia/core/media/mp4_layout_parser.dart';

import 'mp4_layout_fixture.dart';

void main() {
  group('Mp4LayoutParser', () {
    test('正常交错的文件不判异常', () {
      final moov = buildMoov(
        videoOffsets: <int>[
          for (var index = 0; index < 300; index++) 100000 + index * 2400,
        ],
        audioOffsets: <int>[
          for (var index = 0; index < 300; index++)
            100000 + index * 2400 + 1200,
        ],
        useCo64: false,
      );

      final metrics = Mp4LayoutParser.analyze(moov);

      expect(metrics, isNotNull);
      expect(metrics!.isAbnormal, isFalse);
      expect(metrics.maxDistanceBytes, 1200);
      expect(metrics.videoSamples, 300);
      expect(metrics.audioSamples, 300);
      expect(metrics.ratioP90, lessThan(3));
    });

    test('音视频分块相距数 GB 时判异常', () {
      final moov = buildMoov(
        videoOffsets: <int>[
          for (var index = 0; index < 300; index++) index * 10000000,
        ],
        audioOffsets: <int>[
          for (var index = 0; index < 300; index++)
            5000000000 + index * 10000000,
        ],
        useCo64: true,
      );

      final metrics = Mp4LayoutParser.analyze(moov);

      expect(metrics, isNotNull);
      expect(metrics!.isAbnormal, isTrue);
      expect(metrics.maxDistanceBytes, greaterThan(4000000000));
      expect(metrics.spanP90Bytes, greaterThan(4000000000));
      expect(metrics.ratioP90, greaterThan(100));
    });

    test('没有 moov 或数据不足时返回 null', () {
      expect(Mp4LayoutParser.analyze(Uint8List(0)), isNull);
      expect(
        Mp4LayoutParser.analyze(
          Uint8List.fromList(<int>[
            0,
            0,
            0,
            16,
            ...'ftyp'.codeUnits,
            ...'isom'.codeUnits,
            0,
            0,
            0,
            0,
          ]),
        ),
        isNull,
      );
    });

    test('异常大的 stsz 样本数直接放弃解析', () {
      final moov = buildMoovWithRawStsz(<int>[
        0,
        0,
        0,
        1,
        0xFF,
        0xFF,
        0xFF,
        0xFF,
      ]);

      expect(Mp4LayoutParser.analyze(moov), isNull);
    });

    test('截断的 stsz 头返回 null', () {
      expect(
        Mp4LayoutParser.analyze(buildMoovWithRawStsz(<int>[0, 0, 0, 1])),
        isNull,
      );
    });
  });
}
