import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:media_kit/media_kit.dart';
import 'package:sakuramedia/widgets/domain/movies/player/movie_player_native_stats_sampler.dart';

void main() {
  test(
    'ignores a previous media sample that finishes after a playlist switch',
    () async {
      final oldFormat = Completer<String?>();
      var format = oldFormat.future;
      final sampler = MoviePlayerNativeStatsSampler(
        readNativeProperty: (property) =>
            property == 'file-format' ? format : Future.value(null),
        originalUrl: 'https://host/media/1/play/',
      );
      addTearDown(sampler.dispose);
      final oldRefresh = sampler.refreshNative();
      sampler.reset();
      sampler.updateContext(originalUrl: 'https://host/media-clips/2/stream');
      oldFormat.complete('hls');
      await oldRefresh;
      expect(sampler.snapshot.value.playbackStreamTypeLabel, '未确认');
      format = Future.value('mov,mp4');
      await sampler.refreshNative();
      expect(sampler.snapshot.value.playbackStreamTypeLabel, 'HTTP 文件流');
      expect(
        sampler.snapshot.value.playbackGatewayRequestPathLabel,
        '/media-clips/2/stream',
      );
    },
  );

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

    expect(sampler.snapshot.value.playbackDemuxerFormatLabel, 'matroska,webm');
    expect(sampler.snapshot.value.playbackGatewayHostLabel, 'backend.example');
    expect(
      sampler.snapshot.value.playbackGatewayRequestPathLabel,
      contains('/media/1/play/movie.mkv'),
    );
    expect(sampler.snapshot.value.playbackModeLabel, '确认中');
    sampler.updatePlaybackModeLabel('后端代理');
    expect(sampler.snapshot.value.playbackModeLabel, '后端代理');
    sampler.reset();
    expect(sampler.snapshot.value.playbackModeLabel, '确认中');
  });

  test('updates the gateway URL', () {
    final sampler = MoviePlayerNativeStatsSampler(
      readNativeProperty: (_) async => null,
      originalUrl: 'https://backend.example/media/1/play/',
    );
    addTearDown(sampler.dispose);

    sampler.start();
    expect(sampler.snapshot.value.playbackGatewayHostLabel, 'backend.example');
    sampler.updateContext(originalUrl: 'https://proxy.example/media/2/play/');
    expect(sampler.snapshot.value.playbackGatewayHostLabel, 'proxy.example');
    expect(
      sampler.snapshot.value.playbackGatewayRequestPathLabel,
      '/media/2/play/',
    );
  });
}
