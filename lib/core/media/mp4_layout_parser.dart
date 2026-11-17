import 'dart:math' as math;
import 'dart:typed_data';

/// MP4/MOV 音视频交错分析。
///
/// 解析思路裁剪自 miniav_tools_codecs 的 mp4 demuxer（MIT License,
/// Copyright (c) 2025 MichealReed,
/// https://github.com/PracticalXR/miniAV/tree/master/miniav_tools/miniav_tools_codecs）。
/// 这里只保留 stsz/stts/ctts/stsc/stco/co64/elst 与交错指标计算，
/// 去掉了 muxer、codec、platform interface 和 native 依赖。
///
/// MIT License
///
/// Copyright (c) 2025 MichealReed
///
/// Permission is hereby granted, free of charge, to any person obtaining a copy
/// of this software and associated documentation files (the "Software"), to
/// deal in the Software without restriction, including without limitation the
/// rights to use, copy, modify, merge, publish, distribute, sublicense, and/or
/// sell copies of the Software, and to permit persons to whom the Software is
/// furnished to do so, subject to the following conditions:
///
/// The above copyright notice and this permission notice shall be included in
/// all copies or substantial portions of the Software.
///
/// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
/// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
/// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
/// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
/// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
/// FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
/// DEALINGS IN THE SOFTWARE.
class Mp4InterleaveMetrics {
  const Mp4InterleaveMetrics({
    required this.maxDistanceBytes,
    required this.spanP50Bytes,
    required this.spanP90Bytes,
    required this.spanMaxBytes,
    required this.ratioP90,
    required this.videoSamples,
    required this.audioSamples,
  });

  /// 每秒最近音视频 sample 的最大物理距离。
  final int maxDistanceBytes;

  /// 10 秒窗口的数据跨度分位数。
  final int spanP50Bytes;
  final int spanP90Bytes;
  final int spanMaxBytes;

  /// 10 秒窗口“跨度 / 窗口内实际字节数”的 p90。
  final double ratioP90;

  final int videoSamples;
  final int audioSamples;

  static const int abnormalThresholdBytes = 256 * 1024 * 1024;
  static const double abnormalRatio = 20;

  bool get isAbnormal =>
      maxDistanceBytes > abnormalThresholdBytes ||
      spanP90Bytes > abnormalThresholdBytes ||
      ratioP90 > abnormalRatio;
}

class Mp4LayoutParser {
  /// 单条轨道最多解析的 sample 数。超出后放弃静态解析，交给运行时检测；
  /// 损坏/构造文件不能拿未校验的 sample_count 撑爆 isolate 内存。
  static const int _maxSamples = 1000000;

  /// 长片 4K remux 的 stsc 条目可以到几十万（例如每个 chunk 的 sample
  /// 数在 1/2 之间交替），上限不能按普通文件取几百条。
  static const int _maxStscEntries = 1000000;

  static Mp4InterleaveMetrics? analyze(Uint8List moovBytes) {
    if (moovBytes.length < 8) {
      return null;
    }
    try {
      final data = ByteData.sublistView(moovBytes);
      _Box? moov;
      for (final box in _walk(data, 0, data.lengthInBytes)) {
        if (box.type == 'moov') {
          moov = box;
          break;
        }
      }
      if (moov == null) {
        return null;
      }

      var movieTimescale = 1000000;
      final mvhd = _child(data, moov, 'mvhd');
      if (mvhd != null) {
        final version = data.getUint8(mvhd.payloadStart);
        final scaleOffset = mvhd.payloadStart + 4 + (version == 1 ? 16 : 8);
        if (scaleOffset + 4 <= mvhd.payloadEnd) {
          final value = data.getUint32(scaleOffset, Endian.big);
          if (value > 0) {
            movieTimescale = value;
          }
        }
      }

      _Track? video;
      _Track? audio;
      for (final box in _walk(data, moov.payloadStart, moov.payloadEnd)) {
        if (box.type != 'trak') {
          continue;
        }
        final track = _parseTrack(data, box, movieTimescale);
        if (track == null) {
          continue;
        }
        if (track.isVideo && video == null) {
          video = track;
        } else if (!track.isVideo && audio == null) {
          audio = track;
        }
      }
      if (video == null || audio == null) {
        return null;
      }
      if (video.samples.isEmpty || audio.samples.isEmpty) {
        return null;
      }
      return _computeMetrics(video, audio);
    } catch (_) {
      return null;
    }
  }

  static _Track? _parseTrack(ByteData data, _Box trak, int movieTimescale) {
    final mdia = _child(data, trak, 'mdia');
    if (mdia == null) {
      return null;
    }
    final hdlr = _child(data, mdia, 'hdlr');
    if (hdlr == null || hdlr.payloadStart + 12 > hdlr.payloadEnd) {
      return null;
    }
    final handler = _fourcc(data, hdlr.payloadStart + 8);
    final isVideo = handler == 'vide';
    final isAudio = handler == 'soun';
    if (!isVideo && !isAudio) {
      return null;
    }

    final mdhd = _child(data, mdia, 'mdhd');
    if (mdhd == null || mdhd.payloadStart + 4 > mdhd.payloadEnd) {
      return null;
    }
    final version = data.getUint8(mdhd.payloadStart);
    final scaleOffset = mdhd.payloadStart + 4 + (version == 1 ? 16 : 8);
    if (scaleOffset + 4 > mdhd.payloadEnd) {
      return null;
    }
    var timescale = data.getUint32(scaleOffset, Endian.big);
    if (timescale <= 0) {
      timescale = 1000000;
    }

    final minf = _child(data, mdia, 'minf');
    final stbl = minf == null ? null : _child(data, minf, 'stbl');
    if (stbl == null) {
      return null;
    }

    final sizes = _parseStsz(data, _child(data, stbl, 'stsz'));
    if (sizes.isEmpty) {
      return null;
    }
    final durations = _parseStts(
      data,
      _child(data, stbl, 'stts'),
      sizes.length,
    );
    final ctts = _parseCtts(data, _child(data, stbl, 'ctts'), sizes.length);
    final chunkOffsets = _parseChunkOffsets(data, stbl);
    final stsc = _child(data, stbl, 'stsc');
    if (chunkOffsets.isEmpty || stsc == null) {
      return null;
    }
    final offsets = _sampleOffsets(data, stsc, chunkOffsets, sizes);
    if (offsets == null) {
      return null;
    }

    final edit = _parseElst(data, _child(data, trak, 'edts'), movieTimescale);
    final shiftUs = edit.delayUs - _us(edit.mediaStartTicks, timescale);

    final samples = <_Sample>[];
    var dtsTicks = 0;
    for (var index = 0; index < sizes.length; index++) {
      final deltaTicks = durations[index];
      final ptsUs = _us(dtsTicks + ctts[index], timescale) + shiftUs;
      final durationUs =
          _us(dtsTicks + deltaTicks, timescale) - _us(dtsTicks, timescale);
      samples.add(
        _Sample(
          ptsUs: ptsUs,
          durationUs: durationUs < 0 ? 0 : durationUs,
          offset: offsets[index],
          size: sizes[index],
        ),
      );
      dtsTicks += deltaTicks;
    }
    samples.sort((left, right) => left.ptsUs.compareTo(right.ptsUs));
    return _Track(isVideo: isVideo, samples: samples);
  }

  static Mp4InterleaveMetrics _computeMetrics(_Track video, _Track audio) {
    var maxDistance = 0;
    final startUs = math.min(
      video.samples.first.ptsUs,
      audio.samples.first.ptsUs,
    );
    final endUs = math.max(video.samples.last.ptsUs, audio.samples.last.ptsUs);
    const stepUs = 1000000;
    for (var timeUs = startUs; timeUs <= endUs; timeUs += stepUs) {
      final videoSample = _nearest(video.samples, timeUs);
      final audioSample = _nearest(audio.samples, timeUs);
      if (videoSample == null || audioSample == null) {
        continue;
      }
      // 一条轨提前结束时，不要拿它最后的 sample 去和另一条轨很久以后
      // 的数据比较物理距离。
      if ((videoSample.ptsUs - timeUs).abs() > 5000000 ||
          (audioSample.ptsUs - timeUs).abs() > 5000000) {
        continue;
      }
      final distance = (videoSample.offset - audioSample.offset).abs();
      if (distance > maxDistance) {
        maxDistance = distance;
      }
    }

    final spans = <int>[];
    final ratios = <double>[];
    const windowUs = 10 * 1000000;
    for (var timeUs = startUs; timeUs <= endUs; timeUs += windowUs) {
      final videoStats = _rangeStats(video.samples, timeUs, timeUs + windowUs);
      final audioStats = _rangeStats(audio.samples, timeUs, timeUs + windowUs);
      if (videoStats == null || audioStats == null) {
        continue;
      }
      final minOffset = math.min(videoStats.minOffset, audioStats.minOffset);
      final maxOffset = math.max(videoStats.maxOffset, audioStats.maxOffset);
      final span = maxOffset - minOffset;
      final totalBytes = videoStats.totalBytes + audioStats.totalBytes;
      spans.add(span);
      if (totalBytes > 0) {
        ratios.add(span / totalBytes);
      }
    }

    if (spans.isEmpty) {
      return Mp4InterleaveMetrics(
        maxDistanceBytes: maxDistance,
        spanP50Bytes: 0,
        spanP90Bytes: 0,
        spanMaxBytes: 0,
        ratioP90: 0,
        videoSamples: video.samples.length,
        audioSamples: audio.samples.length,
      );
    }

    spans.sort();
    ratios.sort();
    return Mp4InterleaveMetrics(
      maxDistanceBytes: maxDistance,
      spanP50Bytes: spans[spans.length ~/ 2],
      spanP90Bytes:
          spans[math.min(spans.length - 1, (spans.length * 0.9).floor())],
      spanMaxBytes: spans.last,
      ratioP90: ratios.isEmpty
          ? 0
          : ratios[math.min(ratios.length - 1, (ratios.length * 0.9).floor())],
      videoSamples: video.samples.length,
      audioSamples: audio.samples.length,
    );
  }

  static _Sample? _nearest(List<_Sample> samples, int timeUs) {
    final index = _lowerBound(samples, timeUs);
    _Sample? best;
    var bestDistance = 0;
    for (final candidate in <int>[index - 1, index]) {
      if (candidate < 0 || candidate >= samples.length) {
        continue;
      }
      final sample = samples[candidate];
      final distance = (sample.ptsUs - timeUs).abs();
      if (best == null || distance < bestDistance) {
        best = sample;
        bestDistance = distance;
      }
    }
    return best;
  }

  static _RangeStats? _rangeStats(
    List<_Sample> samples,
    int startUs,
    int endUs,
  ) {
    final startIndex = _lowerBound(samples, startUs);
    final endIndex = _lowerBound(samples, endUs);
    if (endIndex <= startIndex) {
      return null;
    }
    var minOffset = samples[startIndex].offset;
    var maxOffset = samples[startIndex].offset;
    var totalBytes = 0;
    for (var index = startIndex; index < endIndex; index++) {
      final sample = samples[index];
      minOffset = math.min(minOffset, sample.offset);
      final endOffset = sample.offset + sample.size;
      if (endOffset > maxOffset) {
        maxOffset = endOffset;
      }
      totalBytes += sample.size;
    }
    return _RangeStats(
      minOffset: minOffset,
      maxOffset: maxOffset,
      totalBytes: totalBytes,
    );
  }

  static int _lowerBound(List<_Sample> samples, int timeUs) {
    var low = 0;
    var high = samples.length;
    while (low < high) {
      final middle = low + (high - low) ~/ 2;
      if (samples[middle].ptsUs < timeUs) {
        low = middle + 1;
      } else {
        high = middle;
      }
    }
    return low;
  }

  static List<int> _parseStsz(ByteData data, _Box? stsz) {
    if (stsz == null || stsz.payloadStart + 12 > stsz.payloadEnd) {
      return const <int>[];
    }
    var offset = stsz.payloadStart + 4;
    final sampleSize = data.getUint32(offset, Endian.big);
    final count = data.getUint32(offset + 4, Endian.big);
    if (count == 0 || count > _maxSamples) {
      return const <int>[];
    }
    offset += 8;
    if (sampleSize != 0) {
      return List<int>.filled(count, sampleSize);
    }
    if (offset + count * 4 > stsz.payloadEnd) {
      return const <int>[];
    }
    final result = List<int>.filled(count, 0);
    for (var index = 0; index < count; index++) {
      result[index] = data.getUint32(offset + index * 4, Endian.big);
    }
    return result;
  }

  static List<int> _parseStts(ByteData data, _Box? stts, int sampleCount) {
    final result = List<int>.filled(sampleCount, 0);
    if (stts == null || stts.payloadStart + 8 > stts.payloadEnd) {
      return result;
    }
    var offset = stts.payloadStart + 4;
    final entryCount = data.getUint32(offset, Endian.big);
    offset += 4;
    var sampleIndex = 0;
    for (
      var entry = 0;
      entry < entryCount && sampleIndex < sampleCount;
      entry++
    ) {
      if (offset + 8 > stts.payloadEnd) {
        break;
      }
      final count = data.getUint32(offset, Endian.big);
      final delta = data.getUint32(offset + 4, Endian.big);
      offset += 8;
      for (var index = 0; index < count && sampleIndex < sampleCount; index++) {
        result[sampleIndex++] = delta;
      }
    }
    return result;
  }

  static List<int> _parseCtts(ByteData data, _Box? ctts, int sampleCount) {
    final result = List<int>.filled(sampleCount, 0);
    if (ctts == null || ctts.payloadStart + 8 > ctts.payloadEnd) {
      return result;
    }
    final version = data.getUint8(ctts.payloadStart);
    var offset = ctts.payloadStart + 4;
    final entryCount = data.getUint32(offset, Endian.big);
    offset += 4;
    var sampleIndex = 0;
    for (
      var entry = 0;
      entry < entryCount && sampleIndex < sampleCount;
      entry++
    ) {
      if (offset + 8 > ctts.payloadEnd) {
        break;
      }
      final count = data.getUint32(offset, Endian.big);
      final value = version == 1
          ? data.getInt32(offset + 4, Endian.big)
          : data.getUint32(offset + 4, Endian.big);
      offset += 8;
      for (var index = 0; index < count && sampleIndex < sampleCount; index++) {
        result[sampleIndex++] = value;
      }
    }
    return result;
  }

  static List<int> _parseChunkOffsets(ByteData data, _Box stbl) {
    final stco = _child(data, stbl, 'stco');
    if (stco != null) {
      if (stco.payloadStart + 8 > stco.payloadEnd) {
        return const <int>[];
      }
      var offset = stco.payloadStart + 4;
      final count = data.getUint32(offset, Endian.big);
      offset += 4;
      if (count == 0 ||
          count > _maxSamples ||
          offset + count * 4 > stco.payloadEnd) {
        return const <int>[];
      }
      return <int>[
        for (var index = 0; index < count; index++)
          data.getUint32(offset + index * 4, Endian.big),
      ];
    }
    final co64 = _child(data, stbl, 'co64');
    if (co64 != null) {
      if (co64.payloadStart + 8 > co64.payloadEnd) {
        return const <int>[];
      }
      var offset = co64.payloadStart + 4;
      final count = data.getUint32(offset, Endian.big);
      offset += 4;
      if (count == 0 ||
          count > _maxSamples ||
          offset + count * 8 > co64.payloadEnd) {
        return const <int>[];
      }
      return <int>[
        for (var index = 0; index < count; index++)
          _readUint64(data, offset + index * 8),
      ];
    }
    return const <int>[];
  }

  static List<int>? _sampleOffsets(
    ByteData data,
    _Box stsc,
    List<int> chunkOffsets,
    List<int> sizes,
  ) {
    if (stsc.payloadStart + 8 > stsc.payloadEnd) {
      return null;
    }
    var offset = stsc.payloadStart + 4;
    final entryCount = data.getUint32(offset, Endian.big);
    offset += 4;
    if (entryCount == 0 ||
        entryCount > _maxStscEntries ||
        offset + entryCount * 12 > stsc.payloadEnd) {
      return null;
    }
    final firstChunk = <int>[];
    final samplesPerChunk = <int>[];
    for (var entry = 0; entry < entryCount; entry++) {
      if (offset + 12 > stsc.payloadEnd) {
        break;
      }
      firstChunk.add(data.getUint32(offset, Endian.big));
      samplesPerChunk.add(data.getUint32(offset + 4, Endian.big));
      offset += 12;
    }
    if (firstChunk.isEmpty) {
      return null;
    }

    final result = List<int>.filled(sizes.length, 0);
    var sampleIndex = 0;
    var entryIndex = 0;
    var perChunk = 1;
    for (
      var chunkIndex = 0;
      chunkIndex < chunkOffsets.length && sampleIndex < sizes.length;
      chunkIndex++
    ) {
      while (entryIndex < firstChunk.length &&
          firstChunk[entryIndex] <= chunkIndex + 1) {
        perChunk = samplesPerChunk[entryIndex];
        entryIndex++;
      }
      var sampleOffset = chunkOffsets[chunkIndex];
      for (
        var index = 0;
        index < perChunk && sampleIndex < sizes.length;
        index++
      ) {
        result[sampleIndex] = sampleOffset;
        sampleOffset += sizes[sampleIndex];
        sampleIndex++;
      }
    }
    if (sampleIndex < sizes.length) {
      return null;
    }
    return result;
  }

  static _EditOrigin _parseElst(ByteData data, _Box? edts, int movieTimescale) {
    if (edts == null || movieTimescale <= 0) {
      return const _EditOrigin(0, 0);
    }
    final elst = _child(data, edts, 'elst');
    if (elst == null || elst.payloadStart + 8 > elst.payloadEnd) {
      return const _EditOrigin(0, 0);
    }
    final version = data.getUint8(elst.payloadStart);
    final entrySize = version == 1 ? 20 : 12;
    var offset = elst.payloadStart + 4;
    final entryCount = data.getUint32(offset, Endian.big);
    offset += 4;
    var delayTicks = 0;
    var mediaStart = 0;
    var foundReal = false;
    for (var entry = 0; entry < entryCount; entry++) {
      if (offset + entrySize > elst.payloadEnd) {
        break;
      }
      final int segmentDuration;
      final int mediaTime;
      if (version == 1) {
        segmentDuration = _readUint64(data, offset);
        mediaTime = _readInt64(data, offset + 8);
      } else {
        segmentDuration = data.getUint32(offset, Endian.big);
        mediaTime = data.getInt32(offset + 4, Endian.big);
      }
      offset += entrySize;
      if (mediaTime < 0) {
        if (!foundReal) {
          delayTicks += segmentDuration;
        }
        continue;
      }
      if (!foundReal) {
        mediaStart = mediaTime;
        foundReal = true;
      }
    }
    return _EditOrigin((delayTicks * 1000000) ~/ movieTimescale, mediaStart);
  }

  static int _us(int ticks, int timescale) => (ticks * 1000000) ~/ timescale;

  static _Box? _child(ByteData data, _Box parent, String type) {
    for (final box in _walk(data, parent.payloadStart, parent.payloadEnd)) {
      if (box.type == type) {
        return box;
      }
    }
    return null;
  }

  static Iterable<_Box> _walk(ByteData data, int start, int end) sync* {
    var position = start;
    while (position + 8 <= end) {
      var size = data.getUint32(position, Endian.big);
      final type = _fourcc(data, position + 4);
      var headerSize = 8;
      if (size == 1) {
        if (position + 16 > end) {
          return;
        }
        size = _readUint64(data, position + 8);
        headerSize = 16;
      } else if (size == 0) {
        size = end - position;
      }
      if (size < headerSize || position + size > end) {
        return;
      }
      yield _Box(
        type: type,
        start: position,
        payloadStart: position + headerSize,
        payloadEnd: position + size,
      );
      position += size;
    }
  }

  static String _fourcc(ByteData data, int offset) {
    if (offset + 4 > data.lengthInBytes) {
      return '';
    }
    return String.fromCharCodes(<int>[
      data.getUint8(offset),
      data.getUint8(offset + 1),
      data.getUint8(offset + 2),
      data.getUint8(offset + 3),
    ]);
  }

  static int _readUint64(ByteData data, int offset) =>
      (data.getUint32(offset, Endian.big) << 32) |
      data.getUint32(offset + 4, Endian.big);

  static int _readInt64(ByteData data, int offset) =>
      data.getInt32(offset, Endian.big) * 0x100000000 +
      data.getUint32(offset + 4, Endian.big);
}

class _Box {
  const _Box({
    required this.type,
    required this.start,
    required this.payloadStart,
    required this.payloadEnd,
  });

  final String type;
  final int start;
  final int payloadStart;
  final int payloadEnd;
}

class _Track {
  const _Track({required this.isVideo, required this.samples});

  final bool isVideo;
  final List<_Sample> samples;
}

class _Sample {
  const _Sample({
    required this.ptsUs,
    required this.durationUs,
    required this.offset,
    required this.size,
  });

  final int ptsUs;
  final int durationUs;
  final int offset;
  final int size;
}

class _RangeStats {
  const _RangeStats({
    required this.minOffset,
    required this.maxOffset,
    required this.totalBytes,
  });

  final int minOffset;
  final int maxOffset;
  final int totalBytes;
}

class _EditOrigin {
  const _EditOrigin(this.delayUs, this.mediaStartTicks);

  final int delayUs;
  final int mediaStartTicks;
}
