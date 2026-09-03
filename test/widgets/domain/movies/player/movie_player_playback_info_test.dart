import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:media_kit/media_kit.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/domain/movies/player/movie_player_playback_info.dart';

MoviePlayerPlaybackInfoSnapshot _snapshot({
  Track track = const Track(),
  VideoParams videoParams = const VideoParams(),
  String? fileFormat,
  String? originalUrl,
  MoviePlayerNetworkConnection? networkConnection,
}) {
  return buildMoviePlayerPlaybackInfoSnapshot(
    track: track,
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
    originalUrl: originalUrl,
    fileFormat: fileFormat,
    networkConnection: networkConnection,
  );
}

void main() {
  test('prefers native hwdec-current for decoding mode', () {
    final snapshot = _snapshot(
      videoParams: const VideoParams(hwPixelformat: 'nv12'),
    );
    expect(snapshot.decodingModeLabel, '硬件解码');
  });

  test('reports gateway context and demuxer', () {
    final snapshot = _snapshot(
      fileFormat: 'matroska,webm',
      originalUrl:
          'https://backend.example.com/media/1/play/movie.mkv?signature=x',
    );

    expect(snapshot.playbackGatewayHostLabel, 'backend.example.com');
    expect(snapshot.playbackGatewayRequestPathLabel, '/media/1/play/movie.mkv');
    expect(snapshot.playbackDemuxerFormatLabel, 'matroska,webm');
  });

  test('reports demuxer format independently of gateway context', () {
    final snapshot = _snapshot(fileFormat: 'hls');

    expect(snapshot.playbackDemuxerFormatLabel, 'hls');
  });

  test('identifies actual direct and proxied FFmpeg connections', () {
    const originalUrl = 'https://backend.example.com/media/1/play/';
    final direct = _snapshot(
      originalUrl: originalUrl,
      networkConnection: const MoviePlayerNetworkConnection(
        host: 'cdn.example.com',
        ip: '203.0.113.8',
        port: 443,
      ),
    );
    final proxied = _snapshot(
      originalUrl: originalUrl,
      networkConnection: const MoviePlayerNetworkConnection(
        host: 'backend.example.com',
        ip: '203.0.113.7',
        port: 443,
      ),
    );

    expect(direct.playbackDeliveryLabel, '直连');
    expect(
      direct.playbackActualConnectionLabel,
      'cdn.example.com → 203.0.113.8:443',
    );
    expect(proxied.playbackDeliveryLabel, '转发');
    expect(
      proxied.playbackActualConnectionLabel,
      'backend.example.com → 203.0.113.7:443',
    );
  });

  test('keeps unknown demuxer format neutral', () {
    final snapshot = _snapshot();
    expect(snapshot.playbackDemuxerFormatLabel, '--');
    expect(snapshot.playbackGatewayHostLabel, isNull);
  });

  test('formats core track diagnostics independently of storage provider', () {
    final snapshot = _snapshot(
      track: const Track(
        video: VideoTrack('1', null, null, codec: 'h264', fps: 24),
      ),
    );
    expect(snapshot.mediaFrameRateLabel, '24 fps');
    expect(snapshot.videoCodecLabel, 'h264');
  });

  testWidgets('panel shows gateway and demuxer as separate facts', (
    tester,
  ) async {
    final info = ValueNotifier<MoviePlayerPlaybackInfoSnapshot>(
      _snapshot(
        fileFormat: 'hls',
        originalUrl:
            'https://backend.example.com/media/1/play/?signature=x&delivery=proxy',
        networkConnection: const MoviePlayerNetworkConnection(
          host: 'backend.example.com',
          ip: '203.0.113.7',
          port: 443,
        ),
      ),
    );
    addTearDown(info.dispose);

    await tester.pumpWidget(
      MaterialApp(
        theme: sakuraThemeData,
        home: Scaffold(
          body: SizedBox(
            width: 480,
            height: 900,
            child: MoviePlayerPlaybackInfoPanel(infoListenable: info),
          ),
        ),
      ),
    );

    expect(find.text('播放链路'), findsOneWidget);
    expect(find.text('网关主机'), findsOneWidget);
    expect(find.text('backend.example.com'), findsOneWidget);
    expect(find.text('实际线路'), findsOneWidget);
    expect(find.text('转发'), findsOneWidget);
    expect(find.text('实际连接'), findsOneWidget);
    expect(
      find.text('backend.example.com → 203.0.113.7:443'),
      findsOneWidget,
    );
    expect(find.text('解复用格式'), findsOneWidget);
    expect(find.text('hls'), findsOneWidget);
    expect(find.textContaining('直链 · demuxer='), findsNothing);
  });
}
