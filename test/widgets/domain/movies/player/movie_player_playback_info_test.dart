import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:media_kit/media_kit.dart';
import 'package:oktoast/oktoast.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/domain/movies/player/movie_player_playback_info.dart';

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

    test('marks cloud115 + hls file-format as HLS source', () {
      final snapshot = _buildMinimalSnapshot(
        mediaOrigin: MoviePlayerPlaybackMediaOrigin.cloud115,
        originalUrl:
            'https://backend.example.com/media/1/stream?expires=1&signature=x',
        fileFormat: 'hls',
        hlsBitrate: 3000000,
        videoParams: const VideoParams(dw: 1920, dh: 1080),
        bufferCacheDurationSeconds: 12.3,
        bufferForwardBytes: 8 * 1024 * 1024,
        downloadRateBytesPerSecond: 2.5 * 1024 * 1024,
      );

      expect(snapshot.playbackSourceKindLabel, 'HLS · demuxer=hls');
      expect(snapshot.playbackSourceHostLabel, 'backend.example.com');
      expect(snapshot.playbackSourceRequestPathLabel, '/media/1/stream');
      expect(snapshot.playbackSourceQualityLabel, '1080p · 3.00 Mbps');
      expect(snapshot.playbackSourceBufferLabel, '12.3s / 8.0 MB');
      expect(snapshot.playbackSourceDownloadRateLabel, '2.5 MB/s');
      expect(snapshot.playbackSourceDegradedHint, isNull);
    });

    test(
      'marks cloud115 + non-hls file-format as direct-degraded with hint',
      () {
        final snapshot = _buildMinimalSnapshot(
          mediaOrigin: MoviePlayerPlaybackMediaOrigin.cloud115,
          originalUrl:
              'https://backend.example.com/media/1/stream?expires=1&signature=x',
          fileFormat: 'mov,mp4,m4a,3gp,3g2,mj2',
        );

        expect(
          snapshot.playbackSourceKindLabel,
          '直链（HLS 不可用） · demuxer=mov,mp4,m4a,3gp,3g2,mj2',
        );
        expect(snapshot.playbackSourceQualityLabel, isNull);
        expect(
          snapshot.playbackSourceDegradedHint,
          'HLS 不可用，可能因未转码 / 账号非 VIP，已回落到原画直链',
        );
      },
    );

    test('marks local media regardless of file-format', () {
      final snapshot = _buildMinimalSnapshot(
        mediaOrigin: MoviePlayerPlaybackMediaOrigin.local,
        originalUrl:
            'https://backend.example.com/media/9/stream?expires=1&signature=x',
        fileFormat: 'matroska,webm',
      );

      expect(
        snapshot.playbackSourceKindLabel,
        '本地文件 · demuxer=matroska,webm',
      );
      expect(snapshot.playbackSourceDegradedHint, isNull);
      expect(snapshot.playbackSourceQualityLabel, isNull);
    });

    test(
      'hides host / path when originalUrl cannot yield them',
      () {
        final snapshot = _buildMinimalSnapshot(
          mediaOrigin: MoviePlayerPlaybackMediaOrigin.unknown,
          originalUrl: '',
          fileFormat: null,
        );

        expect(snapshot.playbackSourceKindLabel, '--');
        expect(snapshot.playbackSourceHostLabel, isNull);
        expect(snapshot.playbackSourceRequestPathLabel, isNull);
      },
    );

    test('keeps port in host when non-standard', () {
      final snapshot = _buildMinimalSnapshot(
        mediaOrigin: MoviePlayerPlaybackMediaOrigin.local,
        originalUrl: 'http://192.168.1.10:8000/media/3/stream?expires=1',
        fileFormat: 'mov,mp4,m4a,3gp,3g2,mj2',
      );

      expect(snapshot.playbackSourceHostLabel, '192.168.1.10:8000');
      expect(snapshot.playbackSourceRequestPathLabel, '/media/3/stream');
    });

    test('formats hls quality with kbps fallback for small bitrates', () {
      final snapshot = _buildMinimalSnapshot(
        mediaOrigin: MoviePlayerPlaybackMediaOrigin.cloud115,
        originalUrl: 'https://a.example.com/media/1/stream',
        fileFormat: 'hls',
        hlsBitrate: 800000,
        videoParams: const VideoParams(dw: 854, dh: 480),
      );

      expect(snapshot.playbackSourceQualityLabel, '480p · 800 Kbps');
    });

    test('hides download rate row when rate is unknown', () {
      final snapshot = _buildMinimalSnapshot(
        mediaOrigin: MoviePlayerPlaybackMediaOrigin.cloud115,
        originalUrl: 'https://a.example.com/media/1/stream',
        fileFormat: 'hls',
        hlsBitrate: 3000000,
        videoParams: const VideoParams(dw: 1920, dh: 1080),
      );

      expect(snapshot.playbackSourceDownloadRateLabel, isNull);
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
              child: MoviePlayerPlaybackInfoPanel(
                infoListenable: notifier,
                mediaInfo: const MoviePlayerMediaInfo(
                  sourceLabel: '115 网盘',
                  libraryLabel: '115 主库',
                  fileSizeLabel: '2.0 GB',
                  durationLabel: '01:01:01',
                  resolutionLabel: '3840x2160',
                ),
              ),
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
      expect(find.text('115 网盘'), findsOneWidget);
      expect(find.text('115 主库'), findsOneWidget);
      expect(
        find.byKey(const Key('movie-player-info-value-media-source')),
        findsOneWidget,
      );

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

    testWidgets('renders playback source rows and skips null fields', (
      WidgetTester tester,
    ) async {
      final notifier = ValueNotifier<MoviePlayerPlaybackInfoSnapshot>(
        _buildMinimalSnapshot(
          mediaOrigin: MoviePlayerPlaybackMediaOrigin.cloud115,
          originalUrl: 'https://backend.example.com/media/1/stream?expires=1',
          fileFormat: 'hls',
          hlsBitrate: 3000000,
          videoParams: const VideoParams(dw: 1920, dh: 1080),
          bufferCacheDurationSeconds: 12.3,
          bufferForwardBytes: 8 * 1024 * 1024,
        ),
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

      expect(find.text('播放源'), findsOneWidget);
      expect(find.text('HLS · demuxer=hls'), findsOneWidget);
      expect(find.text('backend.example.com'), findsOneWidget);
      expect(find.text('/media/1/stream'), findsOneWidget);
      expect(find.text('1080p · 3.00 Mbps'), findsOneWidget);
      expect(find.text('12.3s / 8.0 MB'), findsOneWidget);
      // 无下载速率 → 不渲染该行
      expect(
        find.byKey(
          const Key('movie-player-info-value-playback-source-download-rate'),
        ),
        findsNothing,
      );
      // HLS 场景无降级 hint
      expect(
        find.byKey(
          const Key('movie-player-info-playback-source-degraded-hint'),
        ),
        findsNothing,
      );
    });

    testWidgets('shows degraded hint on direct-degraded snapshot', (
      WidgetTester tester,
    ) async {
      final notifier = ValueNotifier<MoviePlayerPlaybackInfoSnapshot>(
        _buildMinimalSnapshot(
          mediaOrigin: MoviePlayerPlaybackMediaOrigin.cloud115,
          originalUrl: 'https://backend.example.com/media/1/stream',
          fileFormat: 'mov,mp4,m4a,3gp,3g2,mj2',
        ),
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
        find.byKey(
          const Key('movie-player-info-playback-source-degraded-hint'),
        ),
        findsOneWidget,
      );
      expect(
        find.text('HLS 不可用，可能因未转码 / 账号非 VIP，已回落到原画直链'),
        findsOneWidget,
      );
      // 档位行不渲染
      expect(
        find.byKey(
          const Key('movie-player-info-value-playback-source-quality'),
        ),
        findsNothing,
      );
    });

    testWidgets('copy button writes value to clipboard', (
      WidgetTester tester,
    ) async {
      String? copied;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, (call) async {
        if (call.method == 'Clipboard.setData') {
          copied = (call.arguments as Map)['text'] as String?;
        }
        return null;
      });
      addTearDown(() {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(SystemChannels.platform, null);
      });

      final notifier = ValueNotifier<MoviePlayerPlaybackInfoSnapshot>(
        _buildMinimalSnapshot(
          mediaOrigin: MoviePlayerPlaybackMediaOrigin.cloud115,
          originalUrl: 'https://backend.example.com/media/1/stream',
          fileFormat: 'hls',
        ),
      );
      addTearDown(notifier.dispose);

      await tester.pumpWidget(
        OKToast(
          child: MaterialApp(
            theme: sakuraThemeData,
            home: Scaffold(
              body: SizedBox.expand(
                child: MoviePlayerPlaybackInfoPanel(infoListenable: notifier),
              ),
            ),
          ),
        ),
      );

      await tester.tap(
        find.byKey(
          const Key('movie-player-info-copy-playback-source-host'),
        ),
      );
      // toast 会 schedule 一个自动关闭 timer；把它跑完防 "pending timers"。
      await tester.pumpAndSettle(const Duration(seconds: 3));

      expect(copied, 'backend.example.com');
    });
  });
}

MoviePlayerPlaybackInfoSnapshot _buildMinimalSnapshot({
  required MoviePlayerPlaybackMediaOrigin mediaOrigin,
  required String originalUrl,
  required String? fileFormat,
  double? hlsBitrate,
  VideoParams videoParams = const VideoParams(),
  double? bufferCacheDurationSeconds,
  int? bufferForwardBytes,
  double? downloadRateBytesPerSecond,
}) {
  return buildMoviePlayerPlaybackInfoSnapshot(
    track: const Track(),
    videoParams: videoParams,
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
    mediaOrigin: mediaOrigin,
    originalUrl: originalUrl,
    fileFormat: fileFormat,
    hlsBitrate: hlsBitrate,
    bufferCacheDurationSeconds: bufferCacheDurationSeconds,
    bufferForwardBytes: bufferForwardBytes,
    downloadRateBytesPerSecond: downloadRateBytesPerSecond,
  );
}
