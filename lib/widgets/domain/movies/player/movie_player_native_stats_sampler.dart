import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:media_kit/media_kit.dart';
import 'package:sakuramedia/widgets/domain/movies/player/movie_player_media_source.dart';
import 'package:sakuramedia/widgets/domain/movies/player/movie_player_playback_info.dart';

/// 读取 mpv 原生属性(如 `video-bitrate`)的注入点;
/// 生产侧用 [createMediaKitNativePropertyReader] 包一层 `Player.platform`,
/// 测试侧直接喂 map/闭包即可,不需要 media_kit 实例。
typedef MoviePlayerNativePropertyReader = Future<String?> Function(
    String property);

MoviePlayerNativePropertyReader createMediaKitNativePropertyReader(
  Player player,
) {
  return (String property) async {
    final platformPlayer = player.platform;
    if (platformPlayer == null) {
      return null;
    }
    final dynamic nativePlayer = platformPlayer;
    try {
      final raw = await nativePlayer.getProperty(property);
      if (raw is! String) {
        return null;
      }
      final normalized = raw.trim();
      if (normalized.isEmpty) {
        return null;
      }
      return normalized;
    } catch (_) {
      return null;
    }
  };
}

/// 从 libmpv `demuxer-cache-state` 的 stringified value 里挖 `fw-bytes`。
/// media_kit `getProperty` 返回的是 mpv 的字符串化输出，形如
/// `{cache-end=..., fw-bytes=8388608, ...}` 或 JSON 化 `{"fw-bytes": 8388608}`；
/// 用正则宽松匹配数字，任何解析失败都回落 null 让"下载速率"行自动隐藏。
int? parseDemuxerForwardBytes(String? raw) {
  if (raw == null || raw.isEmpty) {
    return null;
  }
  final match = RegExp(
    r'''["']?fw-bytes["']?\s*[:=]\s*(\d+)''',
  ).firstMatch(raw);
  if (match == null) {
    return null;
  }
  final parsed = int.tryParse(match.group(1) ?? '');
  if (parsed == null || parsed < 0) {
    return null;
  }
  return parsed;
}

MoviePlayerPlaybackMediaOrigin moviePlayerPlaybackMediaOriginFor(
  MoviePlayerMediaSourceKind sourceKind,
) {
  return switch (sourceKind) {
    MoviePlayerMediaSourceKind.local => MoviePlayerPlaybackMediaOrigin.local,
    MoviePlayerMediaSourceKind.cloud115 =>
      MoviePlayerPlaybackMediaOrigin.cloud115,
    MoviePlayerMediaSourceKind.unknown =>
      MoviePlayerPlaybackMediaOrigin.unknown,
  };
}

/// 播放信息采样机:聚合两路输入产出 [MoviePlayerPlaybackInfoSnapshot]。
///
/// - **流式输入**(Surface 把 player stream 接进来):track / videoParams /
///   audioParams / audioBitrate;
/// - **原生轮询**([start] 后每秒一次 [refreshNative]):hwdec、码率、fps、
///   丢帧计数(含每秒差分)、demuxer 缓冲与下载速率(字节差分)。
///
/// 快照经 `==` 去抖后写入 [snapshot];Web 端无 NativePlayer,[refreshNative]
/// 直接跳过,快照只反映流式输入。换片时调 [updateContext] + [reset]。
class MoviePlayerNativeStatsSampler {
  MoviePlayerNativeStatsSampler({
    required MoviePlayerNativePropertyReader readNativeProperty,
    required MoviePlayerPlaybackMediaOrigin mediaOrigin,
    required String originalUrl,
    bool isWeb = kIsWeb,
  })  : _readNativeProperty = readNativeProperty,
        _mediaOrigin = mediaOrigin,
        _originalUrl = originalUrl,
        _isWeb = isWeb;

  final MoviePlayerNativePropertyReader _readNativeProperty;
  final bool _isWeb;

  MoviePlayerPlaybackMediaOrigin _mediaOrigin;
  String _originalUrl;

  final ValueNotifier<MoviePlayerPlaybackInfoSnapshot> _snapshotNotifier =
      ValueNotifier<MoviePlayerPlaybackInfoSnapshot>(
    MoviePlayerPlaybackInfoSnapshot.empty,
  );

  ValueListenable<MoviePlayerPlaybackInfoSnapshot> get snapshot =>
      _snapshotNotifier;

  Timer? _timer;
  bool _isRefreshing = false;
  bool _isDisposed = false;

  Track _track = const Track();
  VideoParams _videoParams = const VideoParams();
  AudioParams _audioParams = const AudioParams();
  double? _audioBitrate;
  double? _videoBitrate;
  double? _estimatedVfFps;
  String? _hwdecCurrent;
  double? _frameDropCount;
  double? _decoderFrameDropCount;
  double? _voDelayedFrameCount;
  double? _mistimedFrameCount;
  double? _frameDropPerSecond;
  double? _decoderFrameDropPerSecond;
  double? _voDelayedFramePerSecond;
  double? _mistimedFramePerSecond;
  DateTime? _previousCounterSampleAt;
  double? _previousFrameDropCount;
  double? _previousDecoderFrameDropCount;
  double? _previousVoDelayedFrameCount;
  double? _previousMistimedFrameCount;
  String? _fileFormat;
  double? _hlsBitrate;
  double? _demuxerCacheDurationSeconds;
  int? _demuxerForwardBytes;
  double? _downloadRateBytesPerSecond;
  int? _previousDemuxerForwardBytes;
  DateTime? _previousDemuxerBytesSampleAt;

  /// 立即产出一次快照 + 一次原生轮询,并开启每秒定时轮询。
  void start() {
    _refreshSnapshot();
    _timer ??= Timer.periodic(const Duration(seconds: 1), (_) {
      unawaited(refreshNative());
    });
    unawaited(refreshNative());
  }

  void updateTrack(Track track) {
    _track = track;
    _refreshSnapshot();
  }

  void updateVideoParams(VideoParams params) {
    _videoParams = params;
    _refreshSnapshot();
  }

  void updateAudioParams(AudioParams params) {
    _audioParams = params;
    _refreshSnapshot();
  }

  void updateAudioBitrate(double? bitrate) {
    _audioBitrate = bitrate;
    _refreshSnapshot();
  }

  /// 换片/来源变化时同步快照上下文;不清采样字段,需要清时另调 [reset]。
  void updateContext({
    required MoviePlayerPlaybackMediaOrigin mediaOrigin,
    required String originalUrl,
  }) {
    _mediaOrigin = mediaOrigin;
    _originalUrl = originalUrl;
    _refreshSnapshot();
  }

  /// 清空全部原生采样字段(流式输入保留,player 换片会自然重发)。
  void reset() {
    _videoBitrate = null;
    _estimatedVfFps = null;
    _hwdecCurrent = null;
    _frameDropCount = null;
    _decoderFrameDropCount = null;
    _voDelayedFrameCount = null;
    _mistimedFrameCount = null;
    _frameDropPerSecond = null;
    _decoderFrameDropPerSecond = null;
    _voDelayedFramePerSecond = null;
    _mistimedFramePerSecond = null;
    _previousCounterSampleAt = null;
    _previousFrameDropCount = null;
    _previousDecoderFrameDropCount = null;
    _previousVoDelayedFrameCount = null;
    _previousMistimedFrameCount = null;
    _fileFormat = null;
    _hlsBitrate = null;
    _demuxerCacheDurationSeconds = null;
    _demuxerForwardBytes = null;
    _downloadRateBytesPerSecond = null;
    _previousDemuxerForwardBytes = null;
    _previousDemuxerBytesSampleAt = null;
    _refreshSnapshot();
  }

  Future<void> refreshNative() async {
    if (_isRefreshing || _isWeb || _isDisposed) {
      return;
    }
    _isRefreshing = true;
    try {
      final results = await Future.wait<String?>([
        _readNativeProperty('hwdec-current'),
        _readNativeProperty('video-bitrate'),
        _readNativeProperty('estimated-vf-fps'),
        _readNativeProperty('frame-drop-count'),
        _readNativeProperty('decoder-frame-drop-count'),
        _readNativeProperty('vo-delayed-frame-count'),
        _readNativeProperty('mistimed-frame-count'),
        _readNativeProperty('file-format'),
        _readNativeProperty('hls-bitrate'),
        _readNativeProperty('demuxer-cache-duration'),
        _readNativeProperty('demuxer-cache-state'),
      ]);
      if (_isDisposed) {
        return;
      }
      final now = DateTime.now();
      final frameDropCount = _parseNativeCounter(results[3]);
      final decoderFrameDropCount = _parseNativeCounter(results[4]);
      final voDelayedFrameCount = _parseNativeCounter(results[5]);
      final mistimedFrameCount = _parseNativeCounter(results[6]);
      final fileFormat = results[7];
      final hlsBitrate = _parseNativeDouble(results[8]);
      final cacheDurationSeconds = _parseNativeDouble(results[9]);
      final forwardBytes = parseDemuxerForwardBytes(results[10]);
      final previousSampleAt = _previousCounterSampleAt;
      final elapsedSeconds = previousSampleAt == null
          ? null
          : now.difference(previousSampleAt).inMilliseconds / 1000;

      _hwdecCurrent = results[0];
      _videoBitrate = _parseNativeDouble(results[1]);
      _estimatedVfFps = _parseNativeDouble(results[2]);
      _frameDropCount = frameDropCount;
      _decoderFrameDropCount = decoderFrameDropCount;
      _voDelayedFrameCount = voDelayedFrameCount;
      _mistimedFrameCount = mistimedFrameCount;
      _fileFormat = fileFormat;
      _hlsBitrate = hlsBitrate;
      _demuxerCacheDurationSeconds = cacheDurationSeconds;
      _demuxerForwardBytes = forwardBytes;
      _downloadRateBytesPerSecond = _computeDownloadRatePerSecond(
        currentBytes: forwardBytes,
        previousBytes: _previousDemuxerForwardBytes,
        previousSampleAt: _previousDemuxerBytesSampleAt,
        now: now,
      );
      _frameDropPerSecond = _computeCounterDeltaPerSecond(
        currentValue: frameDropCount,
        previousValue: _previousFrameDropCount,
        elapsedSeconds: elapsedSeconds,
      );
      _decoderFrameDropPerSecond = _computeCounterDeltaPerSecond(
        currentValue: decoderFrameDropCount,
        previousValue: _previousDecoderFrameDropCount,
        elapsedSeconds: elapsedSeconds,
      );
      _voDelayedFramePerSecond = _computeCounterDeltaPerSecond(
        currentValue: voDelayedFrameCount,
        previousValue: _previousVoDelayedFrameCount,
        elapsedSeconds: elapsedSeconds,
      );
      _mistimedFramePerSecond = _computeCounterDeltaPerSecond(
        currentValue: mistimedFrameCount,
        previousValue: _previousMistimedFrameCount,
        elapsedSeconds: elapsedSeconds,
      );
      _previousCounterSampleAt = now;
      _previousFrameDropCount = frameDropCount;
      _previousDecoderFrameDropCount = decoderFrameDropCount;
      _previousVoDelayedFrameCount = voDelayedFrameCount;
      _previousMistimedFrameCount = mistimedFrameCount;
      if (forwardBytes != null) {
        _previousDemuxerForwardBytes = forwardBytes;
        _previousDemuxerBytesSampleAt = now;
      }
      _refreshSnapshot();
    } finally {
      _isRefreshing = false;
    }
  }

  void _refreshSnapshot() {
    if (_isDisposed) {
      return;
    }
    final snapshot = buildMoviePlayerPlaybackInfoSnapshot(
      track: _track,
      videoParams: _videoParams,
      audioParams: _audioParams,
      audioBitrate: _audioBitrate,
      videoBitrate: _videoBitrate,
      estimatedVfFps: _estimatedVfFps,
      hwdecCurrent: _hwdecCurrent,
      renderDropFrameCount: _frameDropCount,
      decoderDropFrameCount: _decoderFrameDropCount,
      delayedFrameCount: _voDelayedFrameCount,
      mistimedFrameCount: _mistimedFrameCount,
      renderDropFramePerSecond: _frameDropPerSecond,
      decoderDropFramePerSecond: _decoderFrameDropPerSecond,
      delayedFramePerSecond: _voDelayedFramePerSecond,
      mistimedFramePerSecond: _mistimedFramePerSecond,
      mediaOrigin: _mediaOrigin,
      originalUrl: _originalUrl,
      fileFormat: _fileFormat,
      hlsBitrate: _hlsBitrate,
      bufferCacheDurationSeconds: _demuxerCacheDurationSeconds,
      bufferForwardBytes: _demuxerForwardBytes,
      downloadRateBytesPerSecond: _downloadRateBytesPerSecond,
    );
    if (_snapshotNotifier.value == snapshot) {
      return;
    }
    _snapshotNotifier.value = snapshot;
  }

  double? _computeDownloadRatePerSecond({
    required int? currentBytes,
    required int? previousBytes,
    required DateTime? previousSampleAt,
    required DateTime now,
  }) {
    if (currentBytes == null ||
        previousBytes == null ||
        previousSampleAt == null) {
      return null;
    }
    final elapsedSeconds =
        now.difference(previousSampleAt).inMilliseconds / 1000;
    if (elapsedSeconds <= 0) {
      return null;
    }
    final delta = currentBytes - previousBytes;
    if (delta <= 0) {
      // 缓冲被消费掉可能出现负 delta；负数不当作速率对外暴露。
      return null;
    }
    final rate = delta / elapsedSeconds;
    if (!rate.isFinite || rate <= 0) {
      return null;
    }
    return rate;
  }

  double? _parseNativeDouble(String? value) {
    if (value == null || value.isEmpty) {
      return null;
    }
    final parsed = double.tryParse(value);
    if (parsed == null || !parsed.isFinite || parsed <= 0) {
      return null;
    }
    return parsed;
  }

  double? _parseNativeCounter(String? value) {
    if (value == null || value.isEmpty) {
      return null;
    }
    final parsed = double.tryParse(value);
    if (parsed == null || !parsed.isFinite || parsed < 0) {
      return null;
    }
    return parsed;
  }

  double? _computeCounterDeltaPerSecond({
    required double? currentValue,
    required double? previousValue,
    required double? elapsedSeconds,
  }) {
    if (currentValue == null ||
        previousValue == null ||
        elapsedSeconds == null ||
        elapsedSeconds <= 0) {
      return null;
    }
    final delta = currentValue - previousValue;
    if (!delta.isFinite || delta < 0) {
      return null;
    }
    final value = delta / elapsedSeconds;
    if (!value.isFinite || value < 0) {
      return null;
    }
    return value;
  }

  void dispose() {
    _isDisposed = true;
    _timer?.cancel();
    _timer = null;
    _snapshotNotifier.dispose();
  }
}
