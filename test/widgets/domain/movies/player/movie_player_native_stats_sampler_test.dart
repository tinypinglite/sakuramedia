import 'package:flutter_test/flutter_test.dart';
import 'package:sakuramedia/widgets/domain/movies/player/movie_player_media_source.dart';
import 'package:sakuramedia/widgets/domain/movies/player/movie_player_native_stats_sampler.dart';
import 'package:sakuramedia/widgets/domain/movies/player/movie_player_playback_info.dart';

void main() {
  MoviePlayerNativeStatsSampler buildSampler({
    required Map<String, String?> properties,
    List<String>? requestLog,
    MoviePlayerPlaybackMediaOrigin mediaOrigin =
        MoviePlayerPlaybackMediaOrigin.cloud115,
    String originalUrl = 'https://backend.example.com/media/1/stream',
    bool isWeb = false,
  }) {
    return MoviePlayerNativeStatsSampler(
      readNativeProperty: (property) async {
        requestLog?.add(property);
        return properties[property];
      },
      mediaOrigin: mediaOrigin,
      originalUrl: originalUrl,
      isWeb: isWeb,
    );
  }

  test('refreshNative 聚合原生属性进快照(解码模式/码率/缓冲)', () async {
    final requestLog = <String>[];
    final sampler = buildSampler(
      requestLog: requestLog,
      properties: <String, String?>{
        'hwdec-current': 'no',
        'video-bitrate': '12500000',
        'file-format': 'hls',
        'demuxer-cache-duration': '12.3',
        'demuxer-cache-state': '{cache-end=60.0, fw-bytes=8388608}',
      },
    );

    await sampler.refreshNative();
    final snapshot = sampler.snapshot.value;

    expect(requestLog, contains('hwdec-current'));
    expect(requestLog, contains('demuxer-cache-state'));
    expect(requestLog.length, 11);
    expect(snapshot.decodingModeLabel, '软件解码');
    expect(snapshot.videoBitrateLabel, '12.5 Mbps');
    expect(snapshot.playbackSourceKindLabel, contains('HLS'));
    expect(snapshot.playbackSourceHostLabel, 'backend.example.com');
    expect(snapshot.playbackSourceBufferLabel, '12.3s / 8.0 MB');
    sampler.dispose();
  });

  test('两次采样间 fw-bytes 增长时产出下载速率', () async {
    var forwardBytes = 1024 * 1024;
    final sampler = MoviePlayerNativeStatsSampler(
      readNativeProperty: (property) async {
        if (property == 'demuxer-cache-state') {
          return '{fw-bytes=$forwardBytes}';
        }
        return null;
      },
      mediaOrigin: MoviePlayerPlaybackMediaOrigin.cloud115,
      originalUrl: 'https://backend.example.com/media/1/stream',
    );

    await sampler.refreshNative();
    expect(sampler.snapshot.value.playbackSourceDownloadRateLabel, isNull);

    forwardBytes += 4 * 1024 * 1024;
    await Future<void>.delayed(const Duration(milliseconds: 20));
    await sampler.refreshNative();

    expect(
      sampler.snapshot.value.playbackSourceDownloadRateLabel,
      isNotNull,
    );
    sampler.dispose();
  });

  test('reset 清空原生采样字段', () async {
    final sampler = buildSampler(
      properties: <String, String?>{
        'video-bitrate': '12500000',
        'demuxer-cache-duration': '12.3',
        'demuxer-cache-state': '{fw-bytes=8388608}',
      },
    );

    await sampler.refreshNative();
    expect(sampler.snapshot.value.playbackSourceBufferLabel, isNotNull);

    sampler.reset();
    expect(sampler.snapshot.value.playbackSourceBufferLabel, isNull);
    expect(sampler.snapshot.value.videoBitrateLabel, '--');
    sampler.dispose();
  });

  test('updateContext 切换来源与地址', () async {
    final sampler = buildSampler(properties: const <String, String?>{});
    await sampler.refreshNative();
    expect(
      sampler.snapshot.value.playbackSourceHostLabel,
      'backend.example.com',
    );

    sampler.updateContext(
      mediaOrigin: MoviePlayerPlaybackMediaOrigin.local,
      originalUrl: 'http://192.168.1.10:8000/library/2.mp4',
    );
    expect(
      sampler.snapshot.value.playbackSourceHostLabel,
      '192.168.1.10:8000',
    );
    sampler.dispose();
  });

  test('updateAudioBitrate 走流式输入路径刷新快照', () {
    final sampler = buildSampler(properties: const <String, String?>{});
    sampler.updateAudioBitrate(260000);
    expect(sampler.snapshot.value.audioBitrateLabel, '0.26 Mbps');
    sampler.dispose();
  });

  test('相同数据的重复采样不触发多余通知(快照 == 去抖)', () async {
    final sampler = buildSampler(
      properties: const <String, String?>{'video-bitrate': '12500000'},
    );
    var notifications = 0;
    sampler.snapshot.addListener(() => notifications++);

    await sampler.refreshNative();
    final afterFirst = notifications;
    await sampler.refreshNative();

    expect(afterFirst, greaterThan(0));
    expect(notifications, afterFirst);
    sampler.dispose();
  });

  test('Web 端跳过原生轮询', () async {
    final requestLog = <String>[];
    final sampler = buildSampler(
      requestLog: requestLog,
      properties: const <String, String?>{},
      isWeb: true,
    );

    await sampler.refreshNative();
    expect(requestLog, isEmpty);
    sampler.dispose();
  });

  test('dispose 后 refreshNative 不再发起读取', () async {
    final requestLog = <String>[];
    final sampler = buildSampler(
      requestLog: requestLog,
      properties: const <String, String?>{},
    );

    sampler.dispose();
    await sampler.refreshNative();
    expect(requestLog, isEmpty);
  });

  test('moviePlayerPlaybackMediaOriginFor 三种来源映射', () {
    expect(
      moviePlayerPlaybackMediaOriginFor(MoviePlayerMediaSourceKind.local),
      MoviePlayerPlaybackMediaOrigin.local,
    );
    expect(
      moviePlayerPlaybackMediaOriginFor(MoviePlayerMediaSourceKind.cloud115),
      MoviePlayerPlaybackMediaOrigin.cloud115,
    );
    expect(
      moviePlayerPlaybackMediaOriginFor(MoviePlayerMediaSourceKind.unknown),
      MoviePlayerPlaybackMediaOrigin.unknown,
    );
  });

  group('parseDemuxerForwardBytes', () {
    test('extracts fw-bytes from mpv-style map string', () {
      expect(
        parseDemuxerForwardBytes(
          '{cache-end=123.4, fw-bytes=8388608, cache-duration=12.3}',
        ),
        8388608,
      );
    });

    test('extracts fw-bytes from JSON-style string', () {
      expect(
        parseDemuxerForwardBytes('{"fw-bytes": 1024, "cache-duration": 3.4}'),
        1024,
      );
    });

    test('returns null when key missing', () {
      expect(parseDemuxerForwardBytes('{cache-duration=12.3}'), isNull);
    });

    test('returns null for null / empty input', () {
      expect(parseDemuxerForwardBytes(null), isNull);
      expect(parseDemuxerForwardBytes(''), isNull);
    });
  });
}
