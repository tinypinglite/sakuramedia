import 'package:flutter_test/flutter_test.dart';
import 'package:sakuramedia/core/media/playback_interleave.dart';
import 'package:sakuramedia/core/media/playback_range_health_detector.dart';

const int _mb = 1024 * 1024;

void main() {
  final t0 = DateTime.utc(2026, 1, 1, 12);

  PlaybackInterleaveSignal? add(
    PlaybackRangeHealthDetector detector,
    int startMb,
    int endMb,
    DateTime at, {
    String cacheKey = 'cloud115:test',
  }) {
    return detector.add(
      cacheKey: cacheKey,
      start: startMb * _mb,
      end: endMb * _mb,
      at: at,
    );
  }

  test('正常顺序预读不触发', () {
    final detector = PlaybackRangeHealthDetector();
    add(detector, 0, 16, t0);
    for (var index = 1; index <= 20; index++) {
      final signal = add(
        detector,
        index * 16,
        index * 16 + 16,
        t0.add(Duration(seconds: 10 + index)),
      );
      expect(signal, isNull);
    }
  });

  test('128MB 连续预读不触发', () {
    final detector = PlaybackRangeHealthDetector();
    add(detector, 0, 128, t0);
    for (var index = 1; index <= 8; index++) {
      final signal = add(
        detector,
        index * 128,
        index * 128 + 128,
        t0.add(Duration(seconds: 10 + index)),
      );
      expect(signal, isNull);
    }
  });

  test('首播读文件尾 moov 再从头读不触发', () {
    final detector = PlaybackRangeHealthDetector();
    add(detector, 7000, 7040, t0);
    for (var index = 0; index <= 8; index++) {
      final signal = add(
        detector,
        index * 16,
        index * 16 + 16,
        t0.add(Duration(seconds: 10 + index)),
      );
      expect(signal, isNull);
    }
  });

  test('用户单次长跳转不触发', () {
    final detector = PlaybackRangeHealthDetector();
    add(detector, 0, 20, t0);
    for (var index = 0; index < 6; index++) {
      add(
        detector,
        index * 20,
        index * 20 + 20,
        t0.add(Duration(seconds: 10 + index)),
      );
    }
    for (var index = 0; index < 6; index++) {
      final signal = add(
        detector,
        5000 + index * 20,
        5000 + index * 20 + 20,
        t0.add(Duration(seconds: 20 + index)),
      );
      expect(signal, isNull);
    }
  });

  test('两个远距离区域反复跳读触发 rangePattern', () {
    final detector = PlaybackRangeHealthDetector();
    add(detector, 0, 20, t0);
    PlaybackInterleaveSignal? signal;
    for (var index = 0; index < 12; index++) {
      final startMb = index.isEven ? 100 : 600;
      signal =
          add(
            detector,
            startMb,
            startMb + 20,
            t0.add(Duration(seconds: 10 + index)),
          ) ??
          signal;
    }

    expect(signal, isNotNull);
    expect(signal!.source, PlaybackInterleaveSource.rangePattern);
    expect(signal.maxDistanceBytes, greaterThan(400 * _mb));
    expect(signal.spanBytes, greaterThan(400 * _mb));
    expect(signal.ratio, isNotNull);
  });

  test('open-ended 请求按起点聚类，两个远距离区域仍触发', () {
    final detector = PlaybackRangeHealthDetector();
    add(detector, 0, 0, t0);
    PlaybackInterleaveSignal? signal;
    for (var index = 0; index < 12; index++) {
      final startMb = index.isEven ? 100 : 600;
      signal =
          add(
            detector,
            startMb,
            startMb,
            t0.add(Duration(seconds: 10 + index)),
          ) ??
          signal;
    }

    expect(signal, isNotNull);
    expect(signal!.source, PlaybackInterleaveSource.rangePattern);
    expect(signal.maxDistanceBytes, greaterThan(400 * _mb));
  });

  test('顺序 open-ended 请求不触发', () {
    final detector = PlaybackRangeHealthDetector();
    add(detector, 0, 0, t0);
    for (var index = 1; index <= 20; index++) {
      final signal = add(
        detector,
        index * 100,
        index * 100,
        t0.add(Duration(seconds: 10 + index)),
      );
      expect(signal, isNull);
    }
  });

  test('拖动后清空窗口，重新出现异常仍可触发', () {
    final detector = PlaybackRangeHealthDetector();
    add(detector, 0, 20, t0);
    for (var index = 0; index < 6; index++) {
      add(
        detector,
        index * 20,
        index * 20 + 20,
        t0.add(Duration(seconds: 10 + index)),
      );
    }

    detector.resetForSeek(t0.add(const Duration(seconds: 30)));
    PlaybackInterleaveSignal? signal;
    for (var index = 0; index < 12; index++) {
      final startMb = index.isEven ? 100 : 600;
      signal =
          add(
            detector,
            startMb,
            startMb + 20,
            t0.add(Duration(seconds: 33 + index)),
          ) ??
          signal;
    }

    expect(signal, isNotNull);
  });
}
