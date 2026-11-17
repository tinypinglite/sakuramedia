import 'dart:math' as math;

import 'package:sakuramedia/core/media/playback_interleave.dart';

/// 播放过程中基于 Range 请求模式的交错异常检测器。
///
/// 它不解析容器：MP4/MKV/AVI 等只要播放器在远距离的两个区域之间反复跳读，
/// 就会被识别。正常的顺序预读、首播读文件尾的 moov、用户单次拖动都不会触发；
/// 只有在两个稳定簇之间来回切换足够多次时才判定异常。
class PlaybackRangeHealthDetector {
  PlaybackRangeHealthDetector({
    this.window = const Duration(seconds: 60),
    this.warmup = const Duration(seconds: 10),
    this.seekIgnore = const Duration(seconds: 2),
    this.minSamplesPerCluster = 3,
    this.minGapBytes = 64 * 1024 * 1024,
    this.gapToRequestRatio = 4,
    this.minAlternations = 3,
    this.maxSamples = 128,
  });

  /// 参与统计的时间窗口。
  final Duration window;

  /// 起播阶段忽略时长，用来跳过读 moov / 起播预读。
  final Duration warmup;

  /// 用户拖动后忽略时长，避免把一次 seek 当成异常。
  final Duration seekIgnore;

  /// 低区/高区各自至少需要的请求数。
  final int minSamplesPerCluster;

  /// 两个簇之间的最小绝对距离。
  final int minGapBytes;

  /// 两个簇的距离至少是请求大小中位数的多少倍。
  final int gapToRequestRatio;

  /// 两个簇之间至少需要来回切换多少次。
  final int minAlternations;

  /// 每 key 最多保留的请求数。
  final int maxSamples;

  final List<_RangeSample> _samples = <_RangeSample>[];
  DateTime? _ignoreUntil;
  bool _emitted = false;

  /// 记录一次 Range 请求；满足条件时返回一次信号。
  PlaybackInterleaveSignal? add({
    required String cacheKey,
    required int start,
    required int end,
    required DateTime at,
  }) {
    if (_emitted || end < start) {
      return null;
    }
    _ignoreUntil ??= at.add(warmup);
    if (at.isBefore(_ignoreUntil!)) {
      return null;
    }

    _samples.add(_RangeSample(start: start, end: end, at: at));
    if (_samples.length > maxSamples) {
      _samples.removeRange(0, _samples.length - maxSamples);
    }
    final cutoff = at.subtract(window);
    _samples.removeWhere((sample) => sample.at.isBefore(cutoff));
    return _evaluate(cacheKey);
  }

  /// 用户拖动进度条后清空窗口；后续仍可重新检测。
  void resetForSeek(DateTime at) {
    _samples.clear();
    _ignoreUntil = at.add(seekIgnore);
  }

  PlaybackInterleaveSignal? _evaluate(String cacheKey) {
    if (_samples.length < minSamplesPerCluster * 2) {
      return null;
    }

    final sorted = List<_RangeSample>.of(_samples)
      ..sort((left, right) => left.start.compareTo(right.start));

    var splitIndex = -1;
    var largestGap = 0;
    for (var index = 1; index < sorted.length; index++) {
      final gap = sorted[index].start - sorted[index - 1].end;
      if (gap > largestGap) {
        largestGap = gap;
        splitIndex = index;
      }
    }
    if (splitIndex < 0 || largestGap <= 0) {
      return null;
    }
    if (splitIndex < minSamplesPerCluster ||
        sorted.length - splitIndex < minSamplesPerCluster) {
      return null;
    }

    final lengths = <int>[
      for (final sample in _samples) sample.end - sample.start + 1,
    ]..sort();
    final medianLength = lengths[lengths.length ~/ 2];
    final requiredGap = math.max(
      minGapBytes,
      medianLength * gapToRequestRatio,
    );
    if (largestGap < requiredGap) {
      return null;
    }

    final boundary = sorted[splitIndex].start;
    var alternations = 0;
    int? lastSide;
    for (final sample in _samples) {
      final side = sample.start < boundary ? 0 : 1;
      if (lastSide != null && side != lastSide) {
        alternations++;
      }
      lastSide = side;
    }
    if (alternations < minAlternations) {
      return null;
    }

    var minStart = sorted.first.start;
    var maxEnd = sorted.first.end;
    var totalBytes = 0;
    for (final sample in _samples) {
      minStart = math.min(minStart, sample.start);
      maxEnd = math.max(maxEnd, sample.end);
      totalBytes += sample.end - sample.start + 1;
    }
    final span = maxEnd - minStart;
    _emitted = true;
    return PlaybackInterleaveSignal(
      cacheKey: cacheKey,
      source: PlaybackInterleaveSource.rangePattern,
      maxDistanceBytes: largestGap,
      spanBytes: span,
      ratio: totalBytes > 0 ? span / totalBytes : null,
    );
  }
}

class _RangeSample {
  const _RangeSample({
    required this.start,
    required this.end,
    required this.at,
  });

  final int start;
  final int end;
  final DateTime at;
}
