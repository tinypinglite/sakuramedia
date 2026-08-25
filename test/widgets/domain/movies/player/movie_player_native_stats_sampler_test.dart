import 'package:flutter_test/flutter_test.dart';
import 'package:media_kit/media_kit.dart';
import 'package:sakuramedia/widgets/domain/movies/player/movie_player_media_source.dart';
import 'package:sakuramedia/widgets/domain/movies/player/movie_player_native_stats_sampler.dart';
import 'package:sakuramedia/widgets/domain/movies/player/movie_player_playback_info.dart';

void main() {
  test('parses demuxer forward bytes from native state', () {
    expect(parseDemuxerForwardBytes('{fw-bytes=8388608}'), 8388608);
    expect(parseDemuxerForwardBytes('{"fw-bytes": 1024}'), 1024);
    expect(parseDemuxerForwardBytes(''), isNull);
  });

  test('samples provider direct playback diagnostics', () async {
    final values = <String, String>{
      'file-format': 'matroska,webm',
      'demuxer-cache-duration': '4.5',
      'demuxer-cache-state': '{fw-bytes=4096}',
    };
    final sampler = MoviePlayerNativeStatsSampler(
      readNativeProperty: (property) async => values[property],
      mediaOrigin: MoviePlayerPlaybackMediaOrigin.provider,
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

    expect(sampler.snapshot.value.playbackSourceKindLabel, contains('直链'));
    expect(sampler.snapshot.value.playbackSourceHostLabel, 'backend.example');
    expect(
      sampler.snapshot.value.playbackSourceRequestPathLabel,
      contains('/media/1/play/movie.mkv'),
    );
  });

  test('source kind conversion always uses provider origin', () {
    expect(
      moviePlayerPlaybackMediaOriginFor(MoviePlayerMediaSourceKind.unknown),
      MoviePlayerPlaybackMediaOrigin.provider,
    );
  });
}
