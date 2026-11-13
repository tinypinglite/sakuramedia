import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:media_kit/media_kit.dart';
import 'package:sakuramedia/core/format/app_number_format.dart';
import 'package:sakuramedia/widgets/base/feedback/app_toast.dart';
import 'package:sakuramedia/widgets/base/actions/app_icon_button.dart';
import 'package:sakuramedia/l10n/app_localizations.dart';
import 'package:sakuramedia/theme.dart';

enum MoviePlayerDecodingMode { hardware, software, unknown }

enum MoviePlayerDynamicRangeMode { hdr, sdr, unknown }

/// 面板左侧 label 列固定宽度。
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

/// 播放器采样快照。
///
/// `playbackGatewayHostLabel` 是播放器最初访问的后端网关主机；
/// `playbackGatewayRequestPathLabel` 是不含签名 query 的网关路径；
/// `playbackModeLabel` 为 `null` 表示尚未确认；
/// `playbackStreamTypeLabel` 为 `null` 表示尚未识别；
/// `playbackSourceBufferLabel` / `playbackSourceDownloadRateLabel` 为 `null`
/// 时对应行不展示。
typedef MoviePlayerPlaybackInfoSnapshot = ({
  String decodingModeLabel,
  String videoCodecLabel,
  String videoDecoderLabel,
  String videoResolutionLabel,
  String mediaFrameRateLabel,
  String filterChainFrameRateLabel,
  String actualOutputFrameRateLabel,
  String videoBitrateLabel,
  String renderDropFrameLabel,
  String decoderDropFrameLabel,
  String delayedFrameLabel,
  String mistimedFrameLabel,
  String videoPixelFormatLabel,
  String audioCodecLabel,
  String audioChannelsLabel,
  String audioSampleRateLabel,
  String audioBitrateLabel,
  String dynamicRangeLabel,
  String dynamicRangeDetailLabel,
  String? playbackGatewayHostLabel,
  String? playbackGatewayRequestPathLabel,
  String? playbackModeLabel,
  String playbackDemuxerFormatLabel,
  String? playbackStreamTypeLabel,
  String? playbackSourceBufferLabel,
  String? playbackSourceDownloadRateLabel,
});

const MoviePlayerPlaybackInfoSnapshot moviePlayerPlaybackInfoSnapshotEmpty = (
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
  playbackGatewayHostLabel: null,
  playbackGatewayRequestPathLabel: null,
  playbackModeLabel: null,
  playbackDemuxerFormatLabel: '--',
  playbackStreamTypeLabel: null,
  playbackSourceBufferLabel: null,
  playbackSourceDownloadRateLabel: null,
);

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
  required AppLocalizations l10n,
  String? originalUrl,
  String? playbackModeLabel,
  String? fileFormat,
  double? bufferCacheDurationSeconds,
  int? bufferForwardBytes,
  double? downloadRateBytesPerSecond,
}) {
  final decodingMode = _resolveDecodingMode(
    hwdecCurrent: hwdecCurrent,
    hwPixelformat: videoParams.hwPixelformat,
  );
  final dynamicRangeMode = _resolveDynamicRangeMode(videoParams);
  final mediaFrameRate = track.video.fps;
  final filterChainFrameRate = estimatedVfFps;
  final targetFrameRate = filterChainFrameRate ?? mediaFrameRate;
  final actualOutputFrameRate = calculateMoviePlayerActualOutputFpsEstimate(
    targetFps: targetFrameRate,
    renderDropPerSecond: renderDropFramePerSecond,
    decoderDropPerSecond: decoderDropFramePerSecond,
  );

  return (
    decodingModeLabel: _buildDecodingModeLabel(
      decodingMode,
      hwdecCurrent,
      l10n,
    ),
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
      l10n: l10n,
    ),
    decoderDropFrameLabel: _formatCounterWithRateLabel(
      count: decoderDropFrameCount,
      perSecond: decoderDropFramePerSecond,
      l10n: l10n,
    ),
    delayedFrameLabel: _formatCounterWithRateLabel(
      count: delayedFrameCount,
      perSecond: delayedFramePerSecond,
      l10n: l10n,
    ),
    mistimedFrameLabel: _formatCounterWithRateLabel(
      count: mistimedFrameCount,
      perSecond: mistimedFramePerSecond,
      l10n: l10n,
    ),
    videoPixelFormatLabel: _buildPixelFormatLabel(videoParams),
    audioCodecLabel: _normalizeTechnicalText(track.audio.codec),
    audioChannelsLabel: _buildAudioChannelsLabel(
      audioParams.hrChannels ?? audioParams.channels ?? track.audio.channels,
      track.audio.audiochannels ?? audioParams.channelCount,
      l10n,
    ),
    audioSampleRateLabel: _formatSampleRateLabel(
      audioParams.sampleRate ?? track.audio.samplerate,
    ),
    audioBitrateLabel: _formatBitrateLabel(
      audioBitrate ?? _castIntToDouble(track.audio.bitrate),
    ),
    dynamicRangeLabel: _buildDynamicRangeLabel(dynamicRangeMode, l10n),
    dynamicRangeDetailLabel: _buildDynamicRangeDetailLabel(videoParams, l10n),
    playbackGatewayHostLabel: _extractHost(originalUrl),
    playbackGatewayRequestPathLabel: _extractPathAndTail(originalUrl),
    playbackModeLabel: playbackModeLabel,
    playbackDemuxerFormatLabel: _normalizeTechnicalText(fileFormat),
    playbackStreamTypeLabel: _resolveStreamType(fileFormat, originalUrl, l10n),
    playbackSourceBufferLabel: _buildBufferLabel(
      cacheDurationSeconds: bufferCacheDurationSeconds,
      forwardBytes: bufferForwardBytes,
    ),
    playbackSourceDownloadRateLabel: _formatDownloadRateLabel(
      downloadRateBytesPerSecond,
    ),
  );
}

String _resolveStreamType(
  String? fileFormat,
  String? originalUrl,
  AppLocalizations l10n,
) {
  final formats = (fileFormat ?? '')
      .toLowerCase()
      .split(',')
      .map((s) => s.trim())
      .toSet();
  if (formats.contains('hls') || formats.contains('applehttp')) {
    return 'HLS';
  }
  final scheme = Uri.tryParse(originalUrl ?? '')?.scheme.toLowerCase();
  const fileFormats = {
    'mov',
    'mp4',
    'matroska',
    'mkv',
    'webm',
    'avi',
    'mpegts',
    'mpeg',
    'flv',
    'asf',
    'ogg',
  };
  if ((scheme == 'http' || scheme == 'https') &&
      formats.any(fileFormats.contains)) {
    return l10n.widgetMoviePlayerHttpStream;
  }
  return l10n.widgetMoviePlayerModeUnconfirmed;
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
  final bytesText = (forwardBytes != null && forwardBytes > 0)
      ? formatFileSize(
          forwardBytes,
          maxDecimals: forwardBytes >= 1024 * 1024 * 1024 ? 2 : 1,
        )
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
  return '${formatFileSize(bytesPerSecond.round(), maxDecimals: bytesPerSecond >= 1024 * 1024 * 1024 ? 2 : 1)}/s';
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
  AppLocalizations l10n,
) {
  return switch (mode) {
    MoviePlayerDecodingMode.hardware =>
      hwdecCurrent == null ||
              hwdecCurrent.trim().isEmpty ||
              hwdecCurrent.trim().toLowerCase() == 'yes'
          ? l10n.widgetMoviePlayerHardwareDecode
          : l10n.widgetMoviePlayerHardwareDecodeWith(hwdecCurrent.trim()),
    MoviePlayerDecodingMode.software => l10n.widgetMoviePlayerSoftwareDecode,
    MoviePlayerDecodingMode.unknown => l10n.commonUnknown,
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

String _buildAudioChannelsLabel(
  String? channelsText,
  int? channelCount,
  AppLocalizations l10n,
) {
  final normalizedText = channelsText?.trim();
  if (normalizedText != null && normalizedText.isNotEmpty) {
    return normalizedText;
  }
  if (channelCount != null && channelCount > 0) {
    return l10n.widgetMoviePlayerAudioChannels(channelCount);
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
  required AppLocalizations l10n,
}) {
  final parts = <String>[];
  if (count case final c? when c.isFinite && c >= 0) {
    parts.add(l10n.widgetMoviePlayerCounterTotal(_formatCounterValue(c)));
  }
  if (perSecond case final p? when p.isFinite && p >= 0) {
    parts.add(l10n.widgetMoviePlayerCounterPerSecond(_formatCounterValue(p)));
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

String _buildDynamicRangeLabel(
  MoviePlayerDynamicRangeMode mode,
  AppLocalizations l10n,
) {
  return switch (mode) {
    MoviePlayerDynamicRangeMode.hdr => 'HDR',
    MoviePlayerDynamicRangeMode.sdr => 'SDR',
    MoviePlayerDynamicRangeMode.unknown => l10n.commonUnknown,
  };
}

String _buildDynamicRangeDetailLabel(
  VideoParams videoParams,
  AppLocalizations l10n,
) {
  final parts = <String>[
    if (_hasText(videoParams.primaries))
      '${l10n.moviePlayerPrimaries} ${videoParams.primaries!.trim()}',
    if (_hasText(videoParams.gamma))
      '${l10n.moviePlayerGamma} ${videoParams.gamma!.trim()}',
    if (_hasText(videoParams.light))
      '${l10n.moviePlayerColorLight} ${videoParams.light!.trim()}',
    if (videoParams.sigPeak != null && videoParams.sigPeak! > 0)
      l10n.widgetMoviePlayerPeak(videoParams.sigPeak!.toStringAsFixed(2)),
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
    final l10n = AppLocalizations.of(context);
    _MoviePlayerPlaybackInfoRowData row(
      String label,
      String value,
      String key, {
      bool copyable = false,
      Key? copyButtonKey,
    }) {
      return _MoviePlayerPlaybackInfoRowData(
        label: label,
        value: value,
        valueKey: Key(key),
        copyable: copyable,
        copyButtonKey: copyButtonKey,
      );
    }

    Widget section(String title, List<_MoviePlayerPlaybackInfoRowData> rows) {
      return _MoviePlayerPlaybackInfoSection(title: title, rows: rows);
    }

    return ValueListenableBuilder<MoviePlayerPlaybackInfoSnapshot>(
      valueListenable: infoListenable,
      builder: (context, info, child) {
        final mediaInfo = this.mediaInfo;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.widgetMoviePlayerInfoTooltip,
              key: const Key('movie-player-info-panel-title'),
              style: resolveAppTextStyle(
                context,
                size: AppTextSize.s18,
                weight: AppTextWeight.semibold,
                tone: AppTextTone.primary,
              ),
            ),
            SizedBox(height: context.appSpacing.md),
            Expanded(
              child: ListView(
                children: [
                  ..._buildPlaybackRouteSection(info, l10n),
                  if (mediaInfo != null) ...[
                    section(l10n.widgetMoviePlayerSectionMedia, [
                      row(
                        l10n.widgetMoviePlayerStorageSource,
                        mediaInfo.sourceLabel,
                        'movie-player-info-value-media-source',
                      ),
                      row(
                        l10n.widgetMoviePlayerMediaLibrary,
                        mediaInfo.libraryLabel,
                        'movie-player-info-value-media-library',
                      ),
                      row(
                        l10n.widgetMoviePlayerFileSize,
                        mediaInfo.fileSizeLabel,
                        'movie-player-info-value-media-file-size',
                      ),
                      row(
                        l10n.widgetMoviePlayerDuration,
                        mediaInfo.durationLabel,
                        'movie-player-info-value-media-duration',
                      ),
                      row(
                        l10n.widgetMoviePlayerRecordedResolution,
                        mediaInfo.resolutionLabel,
                        'movie-player-info-value-media-resolution',
                      ),
                    ]),
                    SizedBox(height: context.appSpacing.md),
                  ],
                  section(l10n.widgetMoviePlayerSectionDecode, [
                    row(
                      l10n.widgetMoviePlayerDecodeMode,
                      info.decodingModeLabel,
                      'movie-player-info-value-decoding-mode',
                    ),
                    row(
                      l10n.widgetMoviePlayerDynamicRange,
                      info.dynamicRangeLabel,
                      'movie-player-info-value-dynamic-range',
                    ),
                    row(
                      l10n.widgetMoviePlayerDynamicRangeDetail,
                      info.dynamicRangeDetailLabel,
                      'movie-player-info-value-dynamic-range-detail',
                    ),
                  ]),
                  SizedBox(height: context.appSpacing.md),
                  section(l10n.widgetMoviePlayerSectionVideo, [
                    row(
                      l10n.widgetMoviePlayerCodec,
                      info.videoCodecLabel,
                      'movie-player-info-value-video-codec',
                    ),
                    row(
                      l10n.widgetMoviePlayerDecoder,
                      info.videoDecoderLabel,
                      'movie-player-info-value-video-decoder',
                    ),
                    row(
                      l10n.widgetMoviePlayerResolution,
                      info.videoResolutionLabel,
                      'movie-player-info-value-video-resolution',
                    ),
                    row(
                      l10n.widgetMoviePlayerMediaFrameRate,
                      info.mediaFrameRateLabel,
                      'movie-player-info-value-video-media-fps',
                    ),
                    row(
                      l10n.widgetMoviePlayerFilterChainFrameRate,
                      info.filterChainFrameRateLabel,
                      'movie-player-info-value-video-filter-fps',
                    ),
                    row(
                      l10n.widgetMoviePlayerActualOutputFrameRate,
                      info.actualOutputFrameRateLabel,
                      'movie-player-info-value-video-actual-fps',
                    ),
                    row(
                      l10n.widgetMoviePlayerBitrate,
                      info.videoBitrateLabel,
                      'movie-player-info-value-video-bitrate',
                    ),
                    row(
                      l10n.widgetMoviePlayerRenderDropped,
                      info.renderDropFrameLabel,
                      'movie-player-info-value-video-render-drop',
                    ),
                    row(
                      l10n.widgetMoviePlayerDecodeDropped,
                      info.decoderDropFrameLabel,
                      'movie-player-info-value-video-decoder-drop',
                    ),
                    row(
                      l10n.widgetMoviePlayerDelayedFrames,
                      info.delayedFrameLabel,
                      'movie-player-info-value-video-delayed-frame',
                    ),
                    if (info.mistimedFrameLabel != '--')
                      row(
                        l10n.widgetMoviePlayerMistimedFrames,
                        info.mistimedFrameLabel,
                        'movie-player-info-value-video-mistimed-frame',
                      ),
                    row(
                      l10n.widgetMoviePlayerPixelFormat,
                      info.videoPixelFormatLabel,
                      'movie-player-info-value-video-pixelformat',
                    ),
                  ]),
                  SizedBox(height: context.appSpacing.md),
                  section(l10n.widgetMoviePlayerSectionAudio, [
                    row(
                      l10n.widgetMoviePlayerCodec,
                      info.audioCodecLabel,
                      'movie-player-info-value-audio-codec',
                    ),
                    row(
                      l10n.widgetMoviePlayerChannels,
                      info.audioChannelsLabel,
                      'movie-player-info-value-audio-channels',
                    ),
                    row(
                      l10n.widgetMoviePlayerSampleRate,
                      info.audioSampleRateLabel,
                      'movie-player-info-value-audio-sample-rate',
                    ),
                    row(
                      l10n.widgetMoviePlayerBitrate,
                      info.audioBitrateLabel,
                      'movie-player-info-value-audio-bitrate',
                    ),
                  ]),
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
  });

  final String title;
  final List<_MoviePlayerPlaybackInfoRowData> rows;

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
              tone: AppTextTone.primary,
            ),
          ),
          SizedBox(height: spacing.sm),
          for (int i = 0; i < rows.length; i++) ...[
            _MoviePlayerPlaybackInfoRow(data: rows[i]),
            if (i != rows.length - 1) SizedBox(height: spacing.xs),
          ],
          SizedBox(height: spacing.sm),
          Divider(height: 1, color: context.appColors.borderSubtle),
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

  Future<void> _handleCopy(BuildContext context) async {
    final l10n = AppLocalizations.of(context);
    await Clipboard.setData(ClipboardData(text: data.value));
    showToast(l10n.widgetMoviePlayerCopied, tone: AppToastTone.success);
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
              tone: AppTextTone.secondary,
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
              tone: AppTextTone.primary,
            ),
          ),
        ),
        if (data.copyable) ...[
          SizedBox(width: context.appSpacing.xs),
          AppIconButton(
            key: data.copyButtonKey,
            size: AppIconButtonSize.mini,
            tooltip: AppLocalizations.of(context).commonCopy,
            onPressed: () => _handleCopy(context),
            iconColor: context.appTextPalette.secondary,
            icon: const Icon(Icons.copy),
          ),
        ],
      ],
    );
  }
}

/// 构建播放器信息面板顶部的「播放链路」段。
List<Widget> _buildPlaybackRouteSection(
  MoviePlayerPlaybackInfoSnapshot info,
  AppLocalizations l10n,
) {
  final rows = <_MoviePlayerPlaybackInfoRowData>[
    if (info.playbackGatewayHostLabel case final host?)
      _MoviePlayerPlaybackInfoRowData(
        label: l10n.widgetMoviePlayerGatewayHost,
        value: host,
        valueKey: const Key('movie-player-info-value-playback-gateway-host'),
        copyable: true,
        copyButtonKey: const Key(
          'movie-player-info-copy-playback-gateway-host',
        ),
      ),
    if (info.playbackGatewayRequestPathLabel case final path?)
      _MoviePlayerPlaybackInfoRowData(
        label: l10n.widgetMoviePlayerGatewayPath,
        value: path,
        valueKey: const Key('movie-player-info-value-playback-gateway-path'),
        copyable: true,
        copyButtonKey: const Key(
          'movie-player-info-copy-playback-gateway-path',
        ),
      ),
    _MoviePlayerPlaybackInfoRowData(
      label: l10n.widgetMoviePlayerPlaybackMode,
      value: info.playbackModeLabel ?? l10n.widgetMoviePlayerModePending,
      valueKey: const Key('movie-player-info-value-playback-mode'),
    ),
    _MoviePlayerPlaybackInfoRowData(
      label: l10n.widgetMoviePlayerStreamType,
      value:
          info.playbackStreamTypeLabel ?? l10n.widgetMoviePlayerModeUnconfirmed,
      valueKey: const Key('movie-player-info-value-stream-type'),
    ),
    _MoviePlayerPlaybackInfoRowData(
      label: l10n.widgetMoviePlayerDemuxerFormat,
      value: info.playbackDemuxerFormatLabel,
      valueKey: const Key('movie-player-info-value-playback-demuxer-format'),
    ),
    if (info.playbackSourceBufferLabel case final buffer?)
      _MoviePlayerPlaybackInfoRowData(
        label: l10n.widgetMoviePlayerBuffer,
        value: buffer,
        valueKey: const Key('movie-player-info-value-playback-source-buffer'),
      ),
    if (info.playbackSourceDownloadRateLabel case final rate?)
      _MoviePlayerPlaybackInfoRowData(
        label: l10n.widgetMoviePlayerDownloadRate,
        value: rate,
        valueKey: const Key(
          'movie-player-info-value-playback-source-download-rate',
        ),
      ),
  ];
  return [
    _MoviePlayerPlaybackInfoSection(
      title: l10n.widgetMoviePlayerSectionPlaybackChain,
      rows: rows,
    ),
  ];
}
