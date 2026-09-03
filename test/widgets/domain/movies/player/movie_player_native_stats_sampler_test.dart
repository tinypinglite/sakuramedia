import 'package:flutter_test/flutter_test.dart';
import 'package:media_kit/media_kit.dart';
import 'package:sakuramedia/widgets/domain/movies/player/movie_player_native_stats_sampler.dart';

void main() {
  test('only emits confirmed FFmpeg TCP endpoints', () {
    final trace = MoviePlayerFfmpegNetworkTrace(
      originalUrl: 'https://backend.example/media/1/play/',
    );
    final gatewayConnection = trace.consume(
      const PlayerLog(
        prefix: 'ffmpeg',
        level: 'debug',
        text: 'tcp: Successfully connected to 203.0.113.7 port 443',
      ),
    );
    final redirect = trace.consume(
      const PlayerLog(
        prefix: 'ffmpeg',
        level: 'trace',
        text: "http: header='Location: https://cdn.example.com/video.mp4'",
      ),
    );
    final directConnection = trace.consume(
      const PlayerLog(
        prefix: 'ffmpeg',
        level: 'debug',
        text: 'tcp: Successfully connected to 203.0.113.8 port 443',
      ),
    );
    final absoluteRequest = trace.consume(
      const PlayerLog(
        prefix: 'ffmpeg',
        level: 'trace',
        text: 'http: request: GET https://edge.example.com/video.mp4',
      ),
    );
    final edgeConnection = trace.consume(
      const PlayerLog(
        prefix: 'ffmpeg',
        level: 'debug',
        text: 'tcp: Successfully connected to 203.0.113.9 port 443',
      ),
    );

    expect(gatewayConnection?.host, 'backend.example');
    expect(gatewayConnection?.ip, '203.0.113.7');
    expect(redirect, isNull);
    expect(directConnection?.host, 'cdn.example.com');
    expect(directConnection?.ip, '203.0.113.8');
    expect(directConnection?.port, 443);
    expect(absoluteRequest, isNull);
    expect(edgeConnection?.host, 'edge.example.com');
    expect(edgeConnection?.ip, '203.0.113.9');
    expect(edgeConnection?.port, 443);
  });

  test('ignores non-FFmpeg and unrelated network logs', () {
    final trace = MoviePlayerFfmpegNetworkTrace(
      originalUrl: 'https://backend.example/media/1/play/',
    );
    expect(
      trace.consume(
        const PlayerLog(
          prefix: 'curl',
          level: 'trace',
          text: 'Connected to cdn.example.com (203.0.113.8) port 443 (#0)',
        ),
      ),
      isNull,
    );
    expect(
      trace.consume(
        const PlayerLog(prefix: 'ffmpeg', level: 'trace', text: 'Trying host'),
      ),
      isNull,
    );
  });

  test('parses demuxer forward bytes from native state', () {
    expect(parseDemuxerForwardBytes('{fw-bytes=8388608}'), 8388608);
    expect(parseDemuxerForwardBytes('{"fw-bytes": 1024}'), 1024);
    expect(parseDemuxerForwardBytes(''), isNull);
  });

  test('samples gateway diagnostics', () async {
    final values = <String, String>{
      'file-format': 'matroska,webm',
      'demuxer-cache-duration': '4.5',
      'demuxer-cache-state': '{fw-bytes=4096}',
    };
    final sampler = MoviePlayerNativeStatsSampler(
      readNativeProperty: (property) async => values[property],
      originalUrl: 'https://backend.example/media/1/play/movie.mkv?signature=x',
    );
    addTearDown(sampler.dispose);

    sampler.updateTrack(
      const Track(
        video: VideoTrack('1', null, null, codec: 'h264', w: 1920, h: 1080),
      ),
    );
    sampler.start();
    await Future<void>.delayed(Duration.zero);

    sampler.updateNetworkLog(
      const PlayerLog(
        prefix: 'ffmpeg',
        level: 'debug',
        text: 'tcp: Successfully connected to 203.0.113.8 port 443',
      ),
    );
    sampler.updateNetworkLog(
      const PlayerLog(
        prefix: 'ffmpeg',
        level: 'trace',
        text: "http: header='Location: https://cdn.example.com/video.mp4'",
      ),
    );
    sampler.updateNetworkLog(
      const PlayerLog(
        prefix: 'ffmpeg',
        level: 'debug',
        text: 'tcp: Successfully connected to 203.0.113.8 port 443',
      ),
    );

    expect(sampler.snapshot.value.playbackDemuxerFormatLabel, 'matroska,webm');
    expect(sampler.snapshot.value.playbackGatewayHostLabel, 'backend.example');
    expect(
      sampler.snapshot.value.playbackGatewayRequestPathLabel,
      contains('/media/1/play/movie.mkv'),
    );
    expect(sampler.snapshot.value.playbackDeliveryLabel, '直连');
    expect(
      sampler.snapshot.value.playbackActualConnectionLabel,
      'cdn.example.com → 203.0.113.8:443',
    );
  });

  test('updates the gateway URL', () {
    final sampler = MoviePlayerNativeStatsSampler(
      readNativeProperty: (_) async => null,
      originalUrl: 'https://backend.example/media/1/play/',
    );
    addTearDown(sampler.dispose);

    sampler.start();
    expect(sampler.snapshot.value.playbackGatewayHostLabel, 'backend.example');
    sampler.updateNetworkLog(
      const PlayerLog(
        prefix: 'ffmpeg',
        level: 'debug',
        text: 'tcp: Successfully connected to 203.0.113.7 port 443',
      ),
    );
    expect(
      sampler.snapshot.value.playbackActualConnectionLabel,
      'backend.example → 203.0.113.7:443',
    );

    sampler.updateContext(originalUrl: 'https://proxy.example/media/2/play/');
    expect(sampler.snapshot.value.playbackGatewayHostLabel, 'proxy.example');
    expect(
      sampler.snapshot.value.playbackGatewayRequestPathLabel,
      '/media/2/play/',
    );
    expect(sampler.snapshot.value.playbackDeliveryLabel, '检测中');
    expect(sampler.snapshot.value.playbackActualConnectionLabel, isNull);
  });
}
