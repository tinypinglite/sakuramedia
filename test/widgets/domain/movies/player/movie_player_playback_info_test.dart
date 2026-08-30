import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:media_kit/media_kit.dart';
import 'package:sakuramedia/features/movies/data/dto/detail/movie_detail_dto.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/domain/movies/player/movie_player_playback_info.dart';

MoviePlayerPlaybackInfoSnapshot _snapshot({
  Track track = const Track(),
  VideoParams videoParams = const VideoParams(),
  MoviePlaybackDelivery playbackDelivery = MoviePlaybackDelivery.proxy,
  String? fileFormat,
  String? originalUrl,
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
    playbackDelivery: playbackDelivery,
    originalUrl: originalUrl,
    fileFormat: fileFormat,
  );
}

void main() {
  test('prefers native hwdec-current for decoding mode', () {
    final snapshot = _snapshot(
      videoParams: const VideoParams(hwPixelformat: 'nv12'),
    );
    expect(snapshot.decodingModeLabel, '硬件解码');
  });

  test('reports backend proxy delivery, gateway context, and demuxer', () {
    final snapshot = _snapshot(
      fileFormat: 'matroska,webm',
      originalUrl:
          'https://backend.example.com/media/1/play/movie.mkv?signature=x',
    );

    expect(snapshot.playbackDeliveryLabel, '后端代理');
    expect(snapshot.playbackGatewayHostLabel, 'backend.example.com');
    expect(snapshot.playbackGatewayRequestPathLabel, '/media/1/play/movie.mkv');
    expect(snapshot.playbackDemuxerFormatLabel, 'matroska,webm');
  });

  test('reports redirect delivery independently of demuxer format', () {
    final snapshot = _snapshot(
      playbackDelivery: MoviePlaybackDelivery.redirect,
      fileFormat: 'hls',
    );

    expect(snapshot.playbackDeliveryLabel, '302直连');
    expect(snapshot.playbackDemuxerFormatLabel, 'hls');
  });

  test('keeps unknown demuxer format neutral', () {
    final snapshot = _snapshot();
    expect(snapshot.playbackDeliveryLabel, '后端代理');
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

  testWidgets('panel shows delivery and demuxer as separate facts', (
    tester,
  ) async {
    final info = ValueNotifier<MoviePlayerPlaybackInfoSnapshot>(
      _snapshot(
        fileFormat: 'hls',
        originalUrl:
            'https://backend.example.com/media/1/play/?signature=x&delivery=proxy',
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
    expect(find.text('交付方式'), findsOneWidget);
    expect(find.text('后端代理'), findsOneWidget);
    expect(find.text('网关主机'), findsOneWidget);
    expect(find.text('backend.example.com'), findsOneWidget);
    expect(find.text('解复用格式'), findsOneWidget);
    expect(find.text('hls'), findsOneWidget);
    expect(find.textContaining('直链 · demuxer='), findsNothing);
  });
}
