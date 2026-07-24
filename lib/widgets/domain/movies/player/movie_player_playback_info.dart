import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:media_kit/media_kit.dart';
import 'package:oktoast/oktoast.dart';
import 'package:sakuramedia/theme.dart';

enum MoviePlayerDecodingMode { hardware, software, unknown }

enum MoviePlayerDynamicRangeMode { hdr, sdr, unknown }

/// 传给 [buildMoviePlayerPlaybackInfoSnapshot] 的媒体归属提示——由调用方从
/// 现有 `MoviePlayerMediaSourceKind`（surface 层）转换而来，避免 `playback_info`
/// 反向依赖 surface。
enum MoviePlayerPlaybackMediaOrigin { local, cloud115, unknown }

/// 播放源的实际形态。由 [MoviePlayerPlaybackMediaOrigin]（媒体归属）+ libmpv
/// `file-format`（真实解析器）联合推导：
/// - [hls]：cloud115 媒体 + libmpv 走 HLS demuxer 打开
/// - [directDegraded]：cloud115 媒体，但 libmpv 走的是渐进 mp4/mkv 等——即
///   后端 `/stream` 因 HLS 不可用（未转码 / 非 VIP / 上游异常）静默降级到直链
/// - [local]：本地媒体
/// - [unknown]：还没拿到 `file-format`，或平台不给（Web）
enum MoviePlayerPlaybackSourceKind { hls, directDegraded, local, unknown }

/// 面板左侧 label 列固定宽度（供 label 列 + 缩进 footnote 复用）。
const double _kLabelColumnWidth = 88;

@immutable
class MoviePlayerMediaInfo {
  const MoviePlayerMediaInfo({
    required this.sourceLabel,
    required this.libraryLabel,
    required this.fileSizeLabel,
    required this.durationLabel,
    required this.resolutionLabel,
  });

  final String sourceLabel;
  final String libraryLabel;
  final String fileSizeLabel;
  final String durationLabel;
  final String resolutionLabel;
}

@immutable
class MoviePlayerPlaybackInfoSnapshot {
  const MoviePlayerPlaybackInfoSnapshot({
    required this.decodingModeLabel,
    required this.videoCodecLabel,
    required this.videoDecoderLabel,
    required this.videoResolutionLabel,
    required this.mediaFrameRateLabel,
    required this.filterChainFrameRateLabel,
    required this.actualOutputFrameRateLabel,
    required this.videoBitrateLabel,
    required this.renderDropFrameLabel,
    required this.decoderDropFrameLabel,
    required this.delayedFrameLabel,
    required this.mistimedFrameLabel,
    required this.videoPixelFormatLabel,
    required this.audioCodecLabel,
    required this.audioChannelsLabel,
    required this.audioSampleRateLabel,
    required this.audioBitrateLabel,
    required this.dynamicRangeLabel,
    required this.dynamicRangeDetailLabel,
    this.playbackSourceKindLabel = '--',
    this.playbackSourceHostLabel,
    this.playbackSourceRequestPathLabel,
    this.playbackSourceQualityLabel,
    this.playbackSourceBufferLabel,
    this.playbackSourceDownloadRateLabel,
    this.playbackSourceDegradedHint,
  });

  static const MoviePlayerPlaybackInfoSnapshot empty =
      MoviePlayerPlaybackInfoSnapshot(
        decodingModeLabel: '--',
        videoCodecLabel: '--',
        videoDecoderLabel: '--',
        videoResolutionLabel: '--',
        mediaFrameRateLabel: '--',
        filterChainFrameRateLabel: '--',
        actualOutputFrameRateLabel: '--',
        videoBitrateLabel: '--',
        renderDropFrameLabel: '--',
        decoderDropFrameLabel: '--',
        delayedFrameLabel: '--',
        mistimedFrameLabel: '--',
        videoPixelFormatLabel: '--',
        audioCodecLabel: '--',
        audioChannelsLabel: '--',
        audioSampleRateLabel: '--',
        audioBitrateLabel: '--',
        dynamicRangeLabel: '--',
        dynamicRangeDetailLabel: '--',
      );

  final String decodingModeLabel;
  final String videoCodecLabel;
  final String videoDecoderLabel;
  final String videoResolutionLabel;
  final String mediaFrameRateLabel;
  final String filterChainFrameRateLabel;
  final String actualOutputFrameRateLabel;
  final String videoBitrateLabel;
  final String renderDropFrameLabel;
  final String decoderDropFrameLabel;
  final String delayedFrameLabel;
  final String mistimedFrameLabel;
  final String videoPixelFormatLabel;
  final String audioCodecLabel;
  final String audioChannelsLabel;
  final String audioSampleRateLabel;
  final String audioBitrateLabel;
  final String dynamicRangeLabel;
  final String dynamicRangeDetailLabel;

  /// 类型标签，例如 `HLS · demuxer=hls` / `直链（HLS 不可用）` / `本地文件` / `--`。
  /// 恒非 null——未知时展示 `--`，永远显示这一行。
  final String playbackSourceKindLabel;

  /// 主机名（如 `cpats01.115.com`）；`null` 表示不展示该行（无法从 URL 解析出 host）。
  final String? playbackSourceHostLabel;

  /// 请求路径（如 `/hls-streams/3000000.m3u8`），不含 query 保护签名；
  /// `null` 表示不展示该行。
  final String? playbackSourceRequestPathLabel;

  /// HLS 档位，例如 `1080p · 3.0 Mbps`；仅 HLS 才有值。`null` = 隐藏该行。
  final String? playbackSourceQualityLabel;

  /// 缓冲：`12.3s / 8.2 MB`；本地文件 / 未拿到时为 `null`。
  final String? playbackSourceBufferLabel;

  /// 下载速率：`2.4 MB/s`；libmpv 不给或还没算出时为 `null`（不展示该行）。
  final String? playbackSourceDownloadRateLabel;

  /// 直链降级时的灰色小字提示；HLS / 本地 时为 `null`。
  final String? playbackSourceDegradedHint;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    return other is MoviePlayerPlaybackInfoSnapshot &&
        other.decodingModeLabel == decodingModeLabel &&
        other.videoCodecLabel == videoCodecLabel &&
        other.videoDecoderLabel == videoDecoderLabel &&
        other.videoResolutionLabel == videoResolutionLabel &&
        other.mediaFrameRateLabel == mediaFrameRateLabel &&
        other.filterChainFrameRateLabel == filterChainFrameRateLabel &&
        other.actualOutputFrameRateLabel == actualOutputFrameRateLabel &&
        other.videoBitrateLabel == videoBitrateLabel &&
        other.renderDropFrameLabel == renderDropFrameLabel &&
        other.decoderDropFrameLabel == decoderDropFrameLabel &&
        other.delayedFrameLabel == delayedFrameLabel &&
        other.mistimedFrameLabel == mistimedFrameLabel &&
        other.videoPixelFormatLabel == videoPixelFormatLabel &&
        other.audioCodecLabel == audioCodecLabel &&
        other.audioChannelsLabel == audioChannelsLabel &&
        other.audioSampleRateLabel == audioSampleRateLabel &&
        other.audioBitrateLabel == audioBitrateLabel &&
        other.dynamicRangeLabel == dynamicRangeLabel &&
        other.dynamicRangeDetailLabel == dynamicRangeDetailLabel &&
        other.playbackSourceKindLabel == playbackSourceKindLabel &&
        other.playbackSourceHostLabel == playbackSourceHostLabel &&
        other.playbackSourceRequestPathLabel ==
            playbackSourceRequestPathLabel &&
        other.playbackSourceQualityLabel == playbackSourceQualityLabel &&
        other.playbackSourceBufferLabel == playbackSourceBufferLabel &&
        other.playbackSourceDownloadRateLabel ==
            playbackSourceDownloadRateLabel &&
        other.playbackSourceDegradedHint == playbackSourceDegradedHint;
  }

  @override
  int get hashCode => Object.hashAll([
    decodingModeLabel,
    videoCodecLabel,
    videoDecoderLabel,
    videoResolutionLabel,
    mediaFrameRateLabel,
    filterChainFrameRateLabel,
    actualOutputFrameRateLabel,
    videoBitrateLabel,
    renderDropFrameLabel,
    decoderDropFrameLabel,
    delayedFrameLabel,
    mistimedFrameLabel,
    videoPixelFormatLabel,
    audioCodecLabel,
    audioChannelsLabel,
    audioSampleRateLabel,
    audioBitrateLabel,
    dynamicRangeLabel,
    dynamicRangeDetailLabel,
    playbackSourceKindLabel,
    playbackSourceHostLabel,
    playbackSourceRequestPathLabel,
    playbackSourceQualityLabel,
    playbackSourceBufferLabel,
    playbackSourceDownloadRateLabel,
    playbackSourceDegradedHint,
  ]);
}

MoviePlayerPlaybackInfoSnapshot buildMoviePlayerPlaybackInfoSnapshot({
  required Track track,
  required VideoParams videoParams,
  required AudioParams audioParams,
  required double? audioBitrate,
  required double? videoBitrate,
  required double? estimatedVfFps,
  required String? hwdecCurrent,
  required double? renderDropFrameCount,
  required double? decoderDropFrameCount,
  required double? delayedFrameCount,
  required double? mistimedFrameCount,
  required double? renderDropFramePerSecond,
  required double? decoderDropFramePerSecond,
  required double? delayedFramePerSecond,
  required double? mistimedFramePerSecond,
  MoviePlayerPlaybackMediaOrigin mediaOrigin =
      MoviePlayerPlaybackMediaOrigin.unknown,
  String? originalUrl,
  String? fileFormat,
  double? hlsBitrate,
  double? bufferCacheDurationSeconds,
  int? bufferForwardBytes,
  double? downloadRateBytesPerSecond,
}) {
  final decodingMode = _resolveDecodingMode(
    hwdecCurrent: hwdecCurrent,
    hwPixelformat: videoParams.hwPixelformat,
  );
  final dynamicRangeMode = _resolveDynamicRangeMode(videoParams);
  final sourceKind = _resolvePlaybackSourceKind(
    mediaOrigin: mediaOrigin,
    fileFormat: fileFormat,
  );
  final mediaFrameRate = track.video.fps;
  final filterChainFrameRate = estimatedVfFps;
  final targetFrameRate = filterChainFrameRate ?? mediaFrameRate;
  final actualOutputFrameRate = calculateMoviePlayerActualOutputFpsEstimate(
    targetFps: targetFrameRate,
    renderDropPerSecond: renderDropFramePerSecond,
    decoderDropPerSecond: decoderDropFramePerSecond,
  );

  return MoviePlayerPlaybackInfoSnapshot(
    decodingModeLabel: _buildDecodingModeLabel(decodingMode, hwdecCurrent),
    videoCodecLabel: _normalizeTechnicalText(track.video.codec),
    videoDecoderLabel: _normalizeTechnicalText(track.video.decoder),
    videoResolutionLabel: _buildResolutionLabel(
      displayWidth: videoParams.dw,
      displayHeight: videoParams.dh,
      streamWidth: track.video.w,
      streamHeight: track.video.h,
    ),
    mediaFrameRateLabel: _formatFpsLabel(mediaFrameRate),
    filterChainFrameRateLabel: _formatFpsLabel(filterChainFrameRate),
    actualOutputFrameRateLabel: _formatFpsLabel(actualOutputFrameRate),
    videoBitrateLabel: _formatBitrateLabel(
      videoBitrate ?? _castIntToDouble(track.video.bitrate),
    ),
    renderDropFrameLabel: _formatCounterWithRateLabel(
      count: renderDropFrameCount,
      perSecond: renderDropFramePerSecond,
    ),
    decoderDropFrameLabel: _formatCounterWithRateLabel(
      count: decoderDropFrameCount,
      perSecond: decoderDropFramePerSecond,
    ),
    delayedFrameLabel: _formatCounterWithRateLabel(
      count: delayedFrameCount,
      perSecond: delayedFramePerSecond,
    ),
    mistimedFrameLabel: _formatCounterWithRateLabel(
      count: mistimedFrameCount,
      perSecond: mistimedFramePerSecond,
    ),
    videoPixelFormatLabel: _buildPixelFormatLabel(videoParams),
    audioCodecLabel: _normalizeTechnicalText(track.audio.codec),
    audioChannelsLabel: _buildAudioChannelsLabel(
      audioParams.hrChannels ?? audioParams.channels ?? track.audio.channels,
      track.audio.audiochannels ?? audioParams.channelCount,
    ),
    audioSampleRateLabel: _formatSampleRateLabel(
      audioParams.sampleRate ?? track.audio.samplerate,
    ),
    audioBitrateLabel: _formatBitrateLabel(
      audioBitrate ?? _castIntToDouble(track.audio.bitrate),
    ),
    dynamicRangeLabel: _buildDynamicRangeLabel(dynamicRangeMode),
    dynamicRangeDetailLabel: _buildDynamicRangeDetailLabel(videoParams),
    playbackSourceKindLabel: _buildPlaybackSourceKindLabel(
      sourceKind: sourceKind,
      fileFormat: fileFormat,
    ),
    playbackSourceHostLabel: _extractHost(originalUrl),
    playbackSourceRequestPathLabel: _extractPathAndTail(originalUrl),
    playbackSourceQualityLabel:
        sourceKind == MoviePlayerPlaybackSourceKind.hls
            ? _buildHlsQualityLabel(
              videoParams: videoParams,
              trackVideo: track.video,
              hlsBitrate: hlsBitrate,
            )
            : null,
    playbackSourceBufferLabel: _buildBufferLabel(
      cacheDurationSeconds: bufferCacheDurationSeconds,
      forwardBytes: bufferForwardBytes,
    ),
    playbackSourceDownloadRateLabel: _formatDownloadRateLabel(
      downloadRateBytesPerSecond,
    ),
    playbackSourceDegradedHint:
        sourceKind == MoviePlayerPlaybackSourceKind.directDegraded
            ? 'HLS 不可用，可能因未转码 / 账号非 VIP，已回落到原画直链'
            : null,
  );
}

MoviePlayerPlaybackSourceKind _resolvePlaybackSourceKind({
  required MoviePlayerPlaybackMediaOrigin mediaOrigin,
  required String? fileFormat,
}) {
  if (mediaOrigin == MoviePlayerPlaybackMediaOrigin.local) {
    return MoviePlayerPlaybackSourceKind.local;
  }
  final normalized = fileFormat?.trim().toLowerCase();
  if (normalized == null || normalized.isEmpty) {
    return MoviePlayerPlaybackSourceKind.unknown;
  }
  final isHls = normalized == 'hls' || normalized.contains('hls');
  if (mediaOrigin == MoviePlayerPlaybackMediaOrigin.cloud115) {
    return isHls
        ? MoviePlayerPlaybackSourceKind.hls
        : MoviePlayerPlaybackSourceKind.directDegraded;
  }
  // unknown 归属：只按 fileFormat 判定；非 HLS 一律视作未知（避免误报"降级"）。
  return isHls
      ? MoviePlayerPlaybackSourceKind.hls
      : MoviePlayerPlaybackSourceKind.unknown;
}

String _buildPlaybackSourceKindLabel({
  required MoviePlayerPlaybackSourceKind sourceKind,
  required String? fileFormat,
}) {
  final formatSuffix =
      _hasText(fileFormat) ? ' · demuxer=${fileFormat!.trim()}' : '';
  return switch (sourceKind) {
    MoviePlayerPlaybackSourceKind.hls => 'HLS$formatSuffix',
    MoviePlayerPlaybackSourceKind.directDegraded => '直链（HLS 不可用）$formatSuffix',
    MoviePlayerPlaybackSourceKind.local => '本地文件$formatSuffix',
    MoviePlayerPlaybackSourceKind.unknown => '--',
  };
}

String? _extractHost(String? url) {
  if (url == null || url.trim().isEmpty) {
    return null;
  }
  final uri = Uri.tryParse(url.trim());
  if (uri == null) {
    return null;
  }
  final host = uri.host.trim();
  if (host.isEmpty) {
    return null;
  }
  if (uri.hasPort && uri.port != 0) {
    return '$host:${uri.port}';
  }
  return host;
}

String? _extractPathAndTail(String? url) {
  if (url == null || url.trim().isEmpty) {
    return null;
  }
  final uri = Uri.tryParse(url.trim());
  if (uri == null) {
    return null;
  }
  final path = uri.path.trim();
  if (path.isEmpty || path == '/') {
    return null;
  }
  return path;
}

String? _buildHlsQualityLabel({
  required VideoParams videoParams,
  required VideoTrack trackVideo,
  required double? hlsBitrate,
}) {
  final height = videoParams.dh ?? trackVideo.h;
  final resolutionTier = _resolveResolutionTier(height);
  final bitrateLabel = _formatHlsBitrateLabel(hlsBitrate);
  if (resolutionTier == null && bitrateLabel == null) {
    return null;
  }
  return [
    if (resolutionTier != null) resolutionTier,
    if (bitrateLabel != null) bitrateLabel,
  ].join(' · ');
}

String? _resolveResolutionTier(int? height) {
  if (height == null || height <= 0) {
    return null;
  }
  if (height >= 2000) {
    return '4K';
  }
  if (height >= 1400) {
    return '1440p';
  }
  if (height >= 1000) {
    return '1080p';
  }
  if (height >= 700) {
    return '720p';
  }
  if (height >= 460) {
    return '480p';
  }
  if (height >= 340) {
    return '360p';
  }
  return '${height}p';
}

String? _formatHlsBitrateLabel(double? bitrate) {
  if (bitrate == null || !bitrate.isFinite || bitrate <= 0) {
    return null;
  }
  final mbps = bitrate / 1000000;
  if (mbps >= 10) {
    return '${mbps.toStringAsFixed(1)} Mbps';
  }
  if (mbps >= 1) {
    return '${mbps.toStringAsFixed(2)} Mbps';
  }
  final kbps = bitrate / 1000;
  return '${kbps.toStringAsFixed(0)} Kbps';
}

String? _buildBufferLabel({
  required double? cacheDurationSeconds,
  required int? forwardBytes,
}) {
  final durationText =
      (cacheDurationSeconds != null &&
              cacheDurationSeconds.isFinite &&
              cacheDurationSeconds > 0)
          ? '${cacheDurationSeconds.toStringAsFixed(1)}s'
          : null;
  final bytesText =
      (forwardBytes != null && forwardBytes > 0)
          ? _formatByteSize(forwardBytes.toDouble())
          : null;
  if (durationText == null && bytesText == null) {
    return null;
  }
  if (durationText != null && bytesText != null) {
    return '$durationText / $bytesText';
  }
  return durationText ?? bytesText!;
}

String? _formatDownloadRateLabel(double? bytesPerSecond) {
  if (bytesPerSecond == null ||
      !bytesPerSecond.isFinite ||
      bytesPerSecond <= 0) {
    return null;
  }
  return '${_formatByteSize(bytesPerSecond)}/s';
}

String _formatByteSize(double bytes) {
  if (bytes >= 1024 * 1024 * 1024) {
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }
  if (bytes >= 1024 * 1024) {
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
  if (bytes >= 1024) {
    return '${(bytes / 1024).toStringAsFixed(1)} KB';
  }
  return '${bytes.toStringAsFixed(0)} B';
}

@visibleForTesting
double? calculateMoviePlayerActualOutputFpsEstimate({
  required double? targetFps,
  required double? renderDropPerSecond,
  required double? decoderDropPerSecond,
}) {
  if (targetFps == null || !targetFps.isFinite || targetFps <= 0) {
    return null;
  }
  if (renderDropPerSecond == null || decoderDropPerSecond == null) {
    return null;
  }
  final effectiveDropPerSecond = renderDropPerSecond + decoderDropPerSecond;
  if (!effectiveDropPerSecond.isFinite || effectiveDropPerSecond < 0) {
    return null;
  }
  final estimated = targetFps - effectiveDropPerSecond;
  if (!estimated.isFinite) {
    return null;
  }
  return estimated <= 0 ? 0 : estimated;
}

double? _castIntToDouble(int? value) {
  if (value == null) {
    return null;
  }
  return value.toDouble();
}

String _buildDecodingModeLabel(
  MoviePlayerDecodingMode mode,
  String? hwdecCurrent,
) {
  return switch (mode) {
    MoviePlayerDecodingMode.hardware =>
      hwdecCurrent == null ||
              hwdecCurrent.trim().isEmpty ||
              hwdecCurrent.trim().toLowerCase() == 'yes'
          ? '硬件解码'
          : '硬件解码 (${hwdecCurrent.trim()})',
    MoviePlayerDecodingMode.software => '软件解码',
    MoviePlayerDecodingMode.unknown => '未知',
  };
}

MoviePlayerDecodingMode _resolveDecodingMode({
  required String? hwdecCurrent,
  required String? hwPixelformat,
}) {
  final normalizedHwdec = hwdecCurrent?.trim().toLowerCase();
  if (normalizedHwdec != null && normalizedHwdec.isNotEmpty) {
    if (normalizedHwdec == 'no') {
      return MoviePlayerDecodingMode.software;
    }
    if (normalizedHwdec == 'yes') {
      return MoviePlayerDecodingMode.hardware;
    }
    return MoviePlayerDecodingMode.hardware;
  }
  final normalizedHwPixelFormat = hwPixelformat?.trim().toLowerCase();
  if (normalizedHwPixelFormat != null && normalizedHwPixelFormat.isNotEmpty) {
    return MoviePlayerDecodingMode.hardware;
  }
  return MoviePlayerDecodingMode.unknown;
}

String _buildResolutionLabel({
  required int? displayWidth,
  required int? displayHeight,
  required int? streamWidth,
  required int? streamHeight,
}) {
  final width = displayWidth ?? streamWidth;
  final height = displayHeight ?? streamHeight;
  if (width == null || height == null || width <= 0 || height <= 0) {
    return '--';
  }
  return '${width}x$height';
}

String _buildPixelFormatLabel(VideoParams videoParams) {
  final pixelFormat = videoParams.pixelformat?.trim();
  final hwPixelFormat = videoParams.hwPixelformat?.trim();
  final hasPixelFormat = pixelFormat != null && pixelFormat.isNotEmpty;
  final hasHwPixelFormat = hwPixelFormat != null && hwPixelFormat.isNotEmpty;
  if (!hasPixelFormat && !hasHwPixelFormat) {
    return '--';
  }
  if (hasPixelFormat && hasHwPixelFormat) {
    return '$pixelFormat / hw: $hwPixelFormat';
  }
  if (hasHwPixelFormat) {
    return 'hw: $hwPixelFormat';
  }
  return pixelFormat!;
}

String _buildAudioChannelsLabel(String? channelsText, int? channelCount) {
  final normalizedText = channelsText?.trim();
  if (normalizedText != null && normalizedText.isNotEmpty) {
    return normalizedText;
  }
  if (channelCount != null && channelCount > 0) {
    return '$channelCount 声道';
  }
  return '--';
}

String _formatSampleRateLabel(int? sampleRate) {
  if (sampleRate == null || sampleRate <= 0) {
    return '--';
  }
  if (sampleRate % 1000 == 0) {
    return '${(sampleRate / 1000).round()} kHz';
  }
  final kHz = (sampleRate / 1000).toStringAsFixed(1);
  return '$kHz kHz';
}

String _formatFpsLabel(double? fps) {
  if (fps == null || fps <= 0) {
    return '--';
  }
  if ((fps - fps.roundToDouble()).abs() < 0.001) {
    return '${fps.round()} fps';
  }
  final formatted = fps
      .toStringAsFixed(2)
      .replaceFirst(RegExp(r'0+$'), '')
      .replaceFirst(RegExp(r'\.$'), '');
  return '$formatted fps';
}

String _formatBitrateLabel(double? bitrate) {
  if (bitrate == null || bitrate <= 0) {
    return '--';
  }
  final mbps = bitrate / 1000000;
  if (mbps >= 10) {
    return '${mbps.toStringAsFixed(1)} Mbps';
  }
  return '${mbps.toStringAsFixed(2)} Mbps';
}

String _formatCounterWithRateLabel({
  required double? count,
  required double? perSecond,
}) {
  final parts = <String>[];
  if (count case final c? when c.isFinite && c >= 0) {
    parts.add('累计 ${_formatCounterValue(c)}');
  }
  if (perSecond case final p? when p.isFinite && p >= 0) {
    parts.add('近1s ${_formatCounterValue(p)}');
  }
  if (parts.isEmpty) {
    return '--';
  }
  return parts.join(' · ');
}

String _formatCounterValue(double value) {
  if ((value - value.roundToDouble()).abs() < 0.001) {
    return value.round().toString();
  }
  return value.toStringAsFixed(2);
}

String _normalizeTechnicalText(String? value) {
  final normalized = value?.trim();
  if (normalized == null || normalized.isEmpty) {
    return '--';
  }
  return normalized;
}

MoviePlayerDynamicRangeMode _resolveDynamicRangeMode(VideoParams videoParams) {
  final light = videoParams.light?.trim().toLowerCase();
  final gamma = videoParams.gamma?.trim().toLowerCase();
  final primaries = videoParams.primaries?.trim().toLowerCase();
  final sigPeak = videoParams.sigPeak;
  final isHdrByLight = light == 'hdr';
  final isHdrByGamma = gamma == 'pq' || gamma == 'hlg';
  final isHdrByPrimaries = primaries == 'bt.2020' || primaries == 'bt2020';
  final isHdrByPeak = sigPeak != null && sigPeak > 1.2;

  if (isHdrByLight || isHdrByGamma || isHdrByPrimaries || isHdrByPeak) {
    return MoviePlayerDynamicRangeMode.hdr;
  }
  if (light == 'sdr' || gamma == 'bt.1886') {
    return MoviePlayerDynamicRangeMode.sdr;
  }
  return MoviePlayerDynamicRangeMode.unknown;
}

String _buildDynamicRangeLabel(MoviePlayerDynamicRangeMode mode) {
  return switch (mode) {
    MoviePlayerDynamicRangeMode.hdr => 'HDR',
    MoviePlayerDynamicRangeMode.sdr => 'SDR',
    MoviePlayerDynamicRangeMode.unknown => '未知',
  };
}

String _buildDynamicRangeDetailLabel(VideoParams videoParams) {
  final parts = <String>[
    if (_hasText(videoParams.primaries)) 'Primaries ${videoParams.primaries}',
    if (_hasText(videoParams.gamma)) 'Gamma ${videoParams.gamma}',
    if (_hasText(videoParams.light)) 'Light ${videoParams.light}',
    if (videoParams.sigPeak != null && videoParams.sigPeak! > 0)
      '峰值 ${videoParams.sigPeak!.toStringAsFixed(2)}',
  ];
  if (parts.isEmpty) {
    return '--';
  }
  return parts.join(' · ');
}

bool _hasText(String? value) {
  final normalized = value?.trim();
  return normalized != null && normalized.isNotEmpty;
}

class MoviePlayerPlaybackInfoPanel extends StatelessWidget {
  const MoviePlayerPlaybackInfoPanel({
    super.key,
    required this.infoListenable,
    this.mediaInfo,
  });

  final ValueListenable<MoviePlayerPlaybackInfoSnapshot> infoListenable;
  final MoviePlayerMediaInfo? mediaInfo;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<MoviePlayerPlaybackInfoSnapshot>(
      valueListenable: infoListenable,
      builder: (context, info, child) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '播放信息',
              key: const Key('movie-player-info-panel-title'),
              style: resolveAppTextStyle(
                context,
                size: AppTextSize.s18,
                weight: AppTextWeight.semibold,
                tone: AppTextTone.onMedia,
              ),
            ),
            SizedBox(height: context.appSpacing.md),
            Expanded(
              child: ListView(
                children: [
                  ..._buildPlaybackSourceSection(info),
                  if (mediaInfo case final mediaInfo?) ...[
                    _MoviePlayerPlaybackInfoSection(
                      title: '媒体',
                      rows: [
                        _MoviePlayerPlaybackInfoRowData(
                          label: '存储来源',
                          value: mediaInfo.sourceLabel,
                          valueKey: const Key(
                            'movie-player-info-value-media-source',
                          ),
                        ),
                        _MoviePlayerPlaybackInfoRowData(
                          label: '媒体库',
                          value: mediaInfo.libraryLabel,
                          valueKey: const Key(
                            'movie-player-info-value-media-library',
                          ),
                        ),
                        _MoviePlayerPlaybackInfoRowData(
                          label: '文件大小',
                          value: mediaInfo.fileSizeLabel,
                          valueKey: const Key(
                            'movie-player-info-value-media-file-size',
                          ),
                        ),
                        _MoviePlayerPlaybackInfoRowData(
                          label: '时长',
                          value: mediaInfo.durationLabel,
                          valueKey: const Key(
                            'movie-player-info-value-media-duration',
                          ),
                        ),
                        _MoviePlayerPlaybackInfoRowData(
                          label: '记录分辨率',
                          value: mediaInfo.resolutionLabel,
                          valueKey: const Key(
                            'movie-player-info-value-media-resolution',
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: context.appSpacing.md),
                  ],
                  _MoviePlayerPlaybackInfoSection(
                    title: '解码与动态范围',
                    rows: [
                      _MoviePlayerPlaybackInfoRowData(
                        label: '解码模式',
                        value: info.decodingModeLabel,
                        valueKey: const Key(
                          'movie-player-info-value-decoding-mode',
                        ),
                      ),
                      _MoviePlayerPlaybackInfoRowData(
                        label: '动态范围',
                        value: info.dynamicRangeLabel,
                        valueKey: const Key(
                          'movie-player-info-value-dynamic-range',
                        ),
                      ),
                      _MoviePlayerPlaybackInfoRowData(
                        label: '动态范围详情',
                        value: info.dynamicRangeDetailLabel,
                        valueKey: const Key(
                          'movie-player-info-value-dynamic-range-detail',
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: context.appSpacing.md),
                  _MoviePlayerPlaybackInfoSection(
                    title: '视频',
                    rows: [
                      _MoviePlayerPlaybackInfoRowData(
                        label: '编码',
                        value: info.videoCodecLabel,
                        valueKey: const Key(
                          'movie-player-info-value-video-codec',
                        ),
                      ),
                      _MoviePlayerPlaybackInfoRowData(
                        label: '解码器',
                        value: info.videoDecoderLabel,
                        valueKey: const Key(
                          'movie-player-info-value-video-decoder',
                        ),
                      ),
                      _MoviePlayerPlaybackInfoRowData(
                        label: '分辨率',
                        value: info.videoResolutionLabel,
                        valueKey: const Key(
                          'movie-player-info-value-video-resolution',
                        ),
                      ),
                      _MoviePlayerPlaybackInfoRowData(
                        label: '媒体帧率',
                        value: info.mediaFrameRateLabel,
                        valueKey: const Key(
                          'movie-player-info-value-video-media-fps',
                        ),
                      ),
                      _MoviePlayerPlaybackInfoRowData(
                        label: '滤镜链帧率',
                        value: info.filterChainFrameRateLabel,
                        valueKey: const Key(
                          'movie-player-info-value-video-filter-fps',
                        ),
                      ),
                      _MoviePlayerPlaybackInfoRowData(
                        label: '实际输出帧率(估算)',
                        value: info.actualOutputFrameRateLabel,
                        valueKey: const Key(
                          'movie-player-info-value-video-actual-fps',
                        ),
                      ),
                      _MoviePlayerPlaybackInfoRowData(
                        label: '码率',
                        value: info.videoBitrateLabel,
                        valueKey: const Key(
                          'movie-player-info-value-video-bitrate',
                        ),
                      ),
                      _MoviePlayerPlaybackInfoRowData(
                        label: '渲染丢帧',
                        value: info.renderDropFrameLabel,
                        valueKey: const Key(
                          'movie-player-info-value-video-render-drop',
                        ),
                      ),
                      _MoviePlayerPlaybackInfoRowData(
                        label: '解码丢帧',
                        value: info.decoderDropFrameLabel,
                        valueKey: const Key(
                          'movie-player-info-value-video-decoder-drop',
                        ),
                      ),
                      _MoviePlayerPlaybackInfoRowData(
                        label: '延迟帧',
                        value: info.delayedFrameLabel,
                        valueKey: const Key(
                          'movie-player-info-value-video-delayed-frame',
                        ),
                      ),
                      if (info.mistimedFrameLabel != '--')
                        _MoviePlayerPlaybackInfoRowData(
                          label: '时间失配帧',
                          value: info.mistimedFrameLabel,
                          valueKey: const Key(
                            'movie-player-info-value-video-mistimed-frame',
                          ),
                        ),
                      _MoviePlayerPlaybackInfoRowData(
                        label: '像素格式',
                        value: info.videoPixelFormatLabel,
                        valueKey: const Key(
                          'movie-player-info-value-video-pixelformat',
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: context.appSpacing.md),
                  _MoviePlayerPlaybackInfoSection(
                    title: '音频',
                    rows: [
                      _MoviePlayerPlaybackInfoRowData(
                        label: '编码',
                        value: info.audioCodecLabel,
                        valueKey: const Key(
                          'movie-player-info-value-audio-codec',
                        ),
                      ),
                      _MoviePlayerPlaybackInfoRowData(
                        label: '声道',
                        value: info.audioChannelsLabel,
                        valueKey: const Key(
                          'movie-player-info-value-audio-channels',
                        ),
                      ),
                      _MoviePlayerPlaybackInfoRowData(
                        label: '采样率',
                        value: info.audioSampleRateLabel,
                        valueKey: const Key(
                          'movie-player-info-value-audio-sample-rate',
                        ),
                      ),
                      _MoviePlayerPlaybackInfoRowData(
                        label: '码率',
                        value: info.audioBitrateLabel,
                        valueKey: const Key(
                          'movie-player-info-value-audio-bitrate',
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _MoviePlayerPlaybackInfoSection extends StatelessWidget {
  const _MoviePlayerPlaybackInfoSection({
    required this.title,
    required this.rows,
    this.footnote,
    this.footnoteKey,
  });

  final String title;
  final List<_MoviePlayerPlaybackInfoRowData> rows;

  /// 段末的灰色小字提示（如"HLS 不可用，已回落到直链"）。null 时不渲染。
  final String? footnote;
  final Key? footnoteKey;

  @override
  Widget build(BuildContext context) {
    final spacing = context.appSpacing;
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: spacing.xs),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: resolveAppTextStyle(
              context,
              size: AppTextSize.s14,
              tone: AppTextTone.onMedia,
            ),
          ),
          SizedBox(height: spacing.sm),
          for (int i = 0; i < rows.length; i++) ...[
            _MoviePlayerPlaybackInfoRow(data: rows[i]),
            if (i != rows.length - 1) SizedBox(height: spacing.xs),
          ],
          if (footnote case final footnote?) ...[
            SizedBox(height: spacing.xs),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(width: _kLabelColumnWidth),
                SizedBox(width: spacing.sm),
                Expanded(
                  child: Text(
                    footnote,
                    key: footnoteKey,
                    style: resolveAppTextStyle(
                      context,
                      size: AppTextSize.s12,
                      tone: AppTextTone.muted,
                    ),
                  ),
                ),
              ],
            ),
          ],
          SizedBox(height: spacing.sm),
          Divider(height: 1, color: Colors.white.withValues(alpha: 0.18)),
          SizedBox(height: spacing.sm),
        ],
      ),
    );
  }
}

class _MoviePlayerPlaybackInfoRowData {
  const _MoviePlayerPlaybackInfoRowData({
    required this.label,
    required this.value,
    required this.valueKey,
    this.copyable = false,
    this.copyButtonKey,
  });

  final String label;
  final String value;
  final Key valueKey;

  /// 是否在行末显示复制按钮，点击后把 [value] 写入剪贴板并 toast 提示。
  final bool copyable;

  /// 复制按钮的 Key（测试锚点）。
  final Key? copyButtonKey;
}

class _MoviePlayerPlaybackInfoRow extends StatelessWidget {
  const _MoviePlayerPlaybackInfoRow({required this.data});

  final _MoviePlayerPlaybackInfoRowData data;

  Future<void> _handleCopy() async {
    await Clipboard.setData(ClipboardData(text: data.value));
    showToast('已复制');
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: _kLabelColumnWidth,
          child: Text(
            data.label,
            style: resolveAppTextStyle(
              context,
              size: AppTextSize.s12,
              tone: AppTextTone.muted,
            ),
          ),
        ),
        SizedBox(width: context.appSpacing.sm),
        Expanded(
          child: Text(
            data.value,
            key: data.valueKey,
            style: resolveAppTextStyle(
              context,
              size: AppTextSize.s12,
              tone: AppTextTone.onMedia,
            ),
          ),
        ),
        if (data.copyable) ...[
          SizedBox(width: context.appSpacing.xs),
          SizedBox(
            width: 24,
            height: 24,
            child: IconButton(
              key: data.copyButtonKey,
              padding: EdgeInsets.zero,
              iconSize: 14,
              tooltip: '复制',
              onPressed: _handleCopy,
              icon: const Icon(Icons.copy, color: Colors.white70),
            ),
          ),
        ],
      ],
    );
  }
}

/// 构建播放器信息面板顶部的「播放源」段——从 [info] 里挑非空字段生成行；
/// 类型行恒展示（`--` 时也在），其余"拿不到就不展示"。
List<Widget> _buildPlaybackSourceSection(MoviePlayerPlaybackInfoSnapshot info) {
  final rows = <_MoviePlayerPlaybackInfoRowData>[
    _MoviePlayerPlaybackInfoRowData(
      label: '类型',
      value: info.playbackSourceKindLabel,
      valueKey: const Key('movie-player-info-value-playback-source-kind'),
    ),
    if (info.playbackSourceHostLabel case final host?)
      _MoviePlayerPlaybackInfoRowData(
        label: '主机',
        value: host,
        valueKey: const Key('movie-player-info-value-playback-source-host'),
        copyable: true,
        copyButtonKey: const Key('movie-player-info-copy-playback-source-host'),
      ),
    if (info.playbackSourceRequestPathLabel case final path?)
      _MoviePlayerPlaybackInfoRowData(
        label: '请求路径',
        value: path,
        valueKey: const Key('movie-player-info-value-playback-source-path'),
        copyable: true,
        copyButtonKey: const Key('movie-player-info-copy-playback-source-path'),
      ),
    if (info.playbackSourceQualityLabel case final quality?)
      _MoviePlayerPlaybackInfoRowData(
        label: '档位',
        value: quality,
        valueKey: const Key('movie-player-info-value-playback-source-quality'),
      ),
    if (info.playbackSourceBufferLabel case final buffer?)
      _MoviePlayerPlaybackInfoRowData(
        label: '缓冲',
        value: buffer,
        valueKey: const Key('movie-player-info-value-playback-source-buffer'),
      ),
    if (info.playbackSourceDownloadRateLabel case final rate?)
      _MoviePlayerPlaybackInfoRowData(
        label: '下载速率',
        value: rate,
        valueKey: const Key(
          'movie-player-info-value-playback-source-download-rate',
        ),
      ),
  ];
  return [
    _MoviePlayerPlaybackInfoSection(
      title: '播放源',
      rows: rows,
      footnote: info.playbackSourceDegradedHint,
      footnoteKey: const Key('movie-player-info-playback-source-degraded-hint'),
    ),
  ];
}
