import 'package:flutter_test/flutter_test.dart';
import 'package:media_kit/media_kit.dart';
import 'package:sakuramedia/features/movies/data/dto/detail/movie_detail_dto.dart';
import 'package:sakuramedia/widgets/domain/movies/player/movie_player_native_stats_sampler.dart';

void main() {
  test('parses demuxer forward bytes from native state', () {
    expect(parseDemuxerForwardBytes('{fw-bytes=8388608}'), 8388608);
    expect(parseDemuxerForwardBytes('{"fw-bytes": 1024}'), 1024);
    expect(parseDemuxerForwardBytes(''), isNull);
  });

  test('samples redirect delivery and gateway diagnostics', () async {
    final values = <String, String>{
      'file-format': 'matroska,webm',
      'demuxer-cache-duration': '4.5',
      'demuxer-cache-state': '{fw-bytes=4096}',
    };
    final sampler = MoviePlayerNativeStatsSampler(
      readNativeProperty: (property) async => values[property],
      playbackDelivery: MoviePlaybackDelivery.redirect,
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

    expect(sampler.snapshot.value.playbackDeliveryLabel, '302直连');
    expect(sampler.snapshot.value.playbackDemuxerFormatLabel, 'matroska,webm');
    expect(sampler.snapshot.value.playbackGatewayHostLabel, 'backend.example');
    expect(
      sampler.snapshot.value.playbackGatewayRequestPathLabel,
      contains('/media/1/play/movie.mkv'),
    );
  });

  test('updates delivery independently of the gateway URL', () {
    final sampler = MoviePlayerNativeStatsSampler(
      readNativeProperty: (_) async => null,
      playbackDelivery: MoviePlaybackDelivery.proxy,
      originalUrl: 'https://backend.example/media/1/play/',
    );
    addTearDown(sampler.dispose);

    sampler.start();
    expect(sampler.snapshot.value.playbackDeliveryLabel, '后端代理');

    sampler.updateContext(
      playbackDelivery: MoviePlaybackDelivery.redirect,
      originalUrl: 'https://backend.example/media/1/play/',
    );
    expect(sampler.snapshot.value.playbackDeliveryLabel, '302直连');
  });
}
