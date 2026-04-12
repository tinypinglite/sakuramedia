import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:sakuramedia/theme.dart';

enum MoviePlayerDecodingMode { hardware, software, unknown }

enum MoviePlayerDynamicRangeMode { hdr, sdr, unknown }

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
        other.dynamicRangeDetailLabel == dynamicRangeDetailLabel;
  }

  @override
  int get hashCode =>
      decodingModeLabel.hashCode ^
      videoCodecLabel.hashCode ^
      videoDecoderLabel.hashCode ^
      videoResolutionLabel.hashCode ^
      mediaFrameRateLabel.hashCode ^
      filterChainFrameRateLabel.hashCode ^
      actualOutputFrameRateLabel.hashCode ^
      videoBitrateLabel.hashCode ^
      renderDropFrameLabel.hashCode ^
      decoderDropFrameLabel.hashCode ^
      delayedFrameLabel.hashCode ^
      mistimedFrameLabel.hashCode ^
      videoPixelFormatLabel.hashCode ^
      audioCodecLabel.hashCode ^
      audioChannelsLabel.hashCode ^
      audioSampleRateLabel.hashCode ^
      audioBitrateLabel.hashCode ^
      dynamicRangeLabel.hashCode ^
      dynamicRangeDetailLabel.hashCode;
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
  );
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

@visibleForTesting
MoviePlayerDecodingMode resolveMoviePlayerDecodingMode({
  required String? hwdecCurrent,
  required String? hwPixelformat,
}) {
  return _resolveDecodingMode(
    hwdecCurrent: hwdecCurrent,
    hwPixelformat: hwPixelformat,
  );
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

@visibleForTesting
MoviePlayerDynamicRangeMode resolveMoviePlayerDynamicRangeMode(
  VideoParams videoParams,
) {
  return _resolveDynamicRangeMode(videoParams);
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
  const MoviePlayerPlaybackInfoPanel({super.key, required this.infoListenable});

  final ValueListenable<MoviePlayerPlaybackInfoSnapshot> infoListenable;

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
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: context.appColors.textOnMedia,
                fontWeight: FontWeight.w700,
              ),
            ),
            SizedBox(height: context.appSpacing.md),
            Expanded(
              child: ListView(
                children: [
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
  });

  final String title;
  final List<_MoviePlayerPlaybackInfoRowData> rows;

  @override
  Widget build(BuildContext context) {
    final spacing = context.appSpacing;
    final colors = context.appColors;
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: spacing.xs),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: colors.textOnMedia,
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(height: spacing.sm),
          for (int i = 0; i < rows.length; i++) ...[
            _MoviePlayerPlaybackInfoRow(data: rows[i]),
            if (i != rows.length - 1) SizedBox(height: spacing.xs),
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
  });

  final String label;
  final String value;
  final Key valueKey;
}

class _MoviePlayerPlaybackInfoRow extends StatelessWidget {
  const _MoviePlayerPlaybackInfoRow({required this.data});

  final _MoviePlayerPlaybackInfoRowData data;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 88,
          child: Text(
            data.label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: colors.textOnMedia.withValues(alpha: 0.72),
            ),
          ),
        ),
        SizedBox(width: context.appSpacing.sm),
        Expanded(
          child: Text(
            data.value,
            key: data.valueKey,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: colors.textOnMedia),
          ),
        ),
      ],
    );
  }
}
