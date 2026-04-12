import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:media_kit/media_kit.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/movie_player/movie_player_playback_info.dart';

void main() {
  group('MoviePlayerPlaybackInfoSnapshot builder', () {
    test('prefers native hwdec-current for decoding mode', () {
      final snapshot = buildMoviePlayerPlaybackInfoSnapshot(
        track: const Track(),
        videoParams: const VideoParams(hwPixelformat: 'nv12'),
        audioParams: const AudioParams(),
        audioBitrate: null,
        videoBitrate: null,
        estimatedVfFps: null,
        hwdecCurrent: 'no',
        renderDropFrameCount: null,
        decoderDropFrameCount: null,
        delayedFrameCount: null,
        mistimedFrameCount: null,
        renderDropFramePerSecond: null,
        decoderDropFramePerSecond: null,
        delayedFramePerSecond: null,
        mistimedFramePerSecond: null,
      );

      expect(snapshot.decodingModeLabel, '软件解码');
    });

    test('falls back to hw-pixelformat when hwdec-current is unavailable', () {
      final snapshot = buildMoviePlayerPlaybackInfoSnapshot(
        track: const Track(),
        videoParams: const VideoParams(hwPixelformat: 'vaapi'),
        audioParams: const AudioParams(),
        audioBitrate: null,
        videoBitrate: null,
        estimatedVfFps: null,
        hwdecCurrent: null,
        renderDropFrameCount: null,
        decoderDropFrameCount: null,
        delayedFrameCount: null,
        mistimedFrameCount: null,
        renderDropFramePerSecond: null,
        decoderDropFramePerSecond: null,
        delayedFramePerSecond: null,
        mistimedFramePerSecond: null,
      );

      expect(snapshot.decodingModeLabel, '硬件解码');
    });

    test('uses estimated vf fps as filter chain frame rate', () {
      final snapshot = buildMoviePlayerPlaybackInfoSnapshot(
        track: const Track(video: VideoTrack('1', null, null, fps: 24.0)),
        videoParams: const VideoParams(),
        audioParams: const AudioParams(),
        audioBitrate: null,
        videoBitrate: null,
        estimatedVfFps: 59.94,
        hwdecCurrent: null,
        renderDropFrameCount: 120,
        decoderDropFrameCount: 80,
        delayedFrameCount: 12,
        mistimedFrameCount: null,
        renderDropFramePerSecond: 3.0,
        decoderDropFramePerSecond: 1.0,
        delayedFramePerSecond: 0.5,
        mistimedFramePerSecond: null,
      );

      expect(snapshot.mediaFrameRateLabel, '24 fps');
      expect(snapshot.filterChainFrameRateLabel, '59.94 fps');
      expect(snapshot.actualOutputFrameRateLabel, '55.94 fps');
      expect(snapshot.renderDropFrameLabel, '累计 120 · 近1s 3');
      expect(snapshot.decoderDropFrameLabel, '累计 80 · 近1s 1');
    });

    test('marks hdr when gamma is pq and keeps detail fields', () {
      final snapshot = buildMoviePlayerPlaybackInfoSnapshot(
        track: const Track(),
        videoParams: const VideoParams(
          primaries: 'bt.2020',
          gamma: 'pq',
          light: 'hdr',
          sigPeak: 1000,
        ),
        audioParams: const AudioParams(),
        audioBitrate: null,
        videoBitrate: null,
        estimatedVfFps: null,
        hwdecCurrent: null,
        renderDropFrameCount: null,
        decoderDropFrameCount: null,
        delayedFrameCount: null,
        mistimedFrameCount: null,
        renderDropFramePerSecond: null,
        decoderDropFramePerSecond: null,
        delayedFramePerSecond: null,
        mistimedFramePerSecond: null,
      );

      expect(snapshot.dynamicRangeLabel, 'HDR');
      expect(snapshot.dynamicRangeDetailLabel, contains('Primaries bt.2020'));
      expect(snapshot.dynamicRangeDetailLabel, contains('Gamma pq'));
      expect(snapshot.dynamicRangeDetailLabel, contains('Light hdr'));
    });

    test('formats bitrate and sample rate labels', () {
      final snapshot = buildMoviePlayerPlaybackInfoSnapshot(
        track: const Track(
          audio: AudioTrack('1', null, null, samplerate: 48000),
        ),
        videoParams: const VideoParams(),
        audioParams: const AudioParams(),
        audioBitrate: 256000,
        videoBitrate: 12500000,
        estimatedVfFps: null,
        hwdecCurrent: null,
        renderDropFrameCount: null,
        decoderDropFrameCount: null,
        delayedFrameCount: null,
        mistimedFrameCount: null,
        renderDropFramePerSecond: null,
        decoderDropFramePerSecond: null,
        delayedFramePerSecond: null,
        mistimedFramePerSecond: null,
      );

      expect(snapshot.videoBitrateLabel, '12.5 Mbps');
      expect(snapshot.audioBitrateLabel, '0.26 Mbps');
      expect(snapshot.audioSampleRateLabel, '48 kHz');
    });

    test('returns null actual output fps without drop rate samples', () {
      final actual = calculateMoviePlayerActualOutputFpsEstimate(
        targetFps: 60,
        renderDropPerSecond: null,
        decoderDropPerSecond: 1.0,
      );

      expect(actual, isNull);
    });
  });

  group('MoviePlayerPlaybackInfoPanel', () {
    testWidgets('renders stable keys and updates from notifier', (
      WidgetTester tester,
    ) async {
      final notifier = ValueNotifier<MoviePlayerPlaybackInfoSnapshot>(
        MoviePlayerPlaybackInfoSnapshot.empty,
      );
      addTearDown(notifier.dispose);

      await tester.pumpWidget(
        MaterialApp(
          theme: sakuraThemeData,
          home: Scaffold(
            body: SizedBox.expand(
              child: MoviePlayerPlaybackInfoPanel(infoListenable: notifier),
            ),
          ),
        ),
      );

      expect(
        find.byKey(const Key('movie-player-info-panel-title')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('movie-player-info-value-video-bitrate')),
        findsOneWidget,
      );
      expect(find.text('--'), findsWidgets);

      notifier.value = const MoviePlayerPlaybackInfoSnapshot(
        decodingModeLabel: '硬件解码 (videotoolbox)',
        videoCodecLabel: 'h264',
        videoDecoderLabel: 'h264',
        videoResolutionLabel: '1920x1080',
        mediaFrameRateLabel: '60 fps',
        filterChainFrameRateLabel: '59.94 fps',
        actualOutputFrameRateLabel: '58.50 fps',
        videoBitrateLabel: '8.00 Mbps',
        renderDropFrameLabel: '累计 120 · 近1s 2',
        decoderDropFrameLabel: '累计 30 · 近1s 0',
        delayedFrameLabel: '累计 42 · 近1s 1',
        mistimedFrameLabel: '--',
        videoPixelFormatLabel: 'yuv420p / hw: nv12',
        audioCodecLabel: 'aac',
        audioChannelsLabel: 'stereo',
        audioSampleRateLabel: '48 kHz',
        audioBitrateLabel: '0.26 Mbps',
        dynamicRangeLabel: 'SDR',
        dynamicRangeDetailLabel: 'Primaries bt.709',
      );
      await tester.pump();

      expect(find.text('硬件解码 (videotoolbox)'), findsOneWidget);
      expect(find.text('8.00 Mbps'), findsOneWidget);
      expect(find.text('Primaries bt.709'), findsOneWidget);
      expect(find.text('58.50 fps'), findsOneWidget);
      expect(find.text('累计 120 · 近1s 2'), findsOneWidget);
    });
  });
}
