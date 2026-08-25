import 'package:flutter_test/flutter_test.dart';
import 'package:media_kit/media_kit.dart';
import 'package:sakuramedia/widgets/domain/movies/player/movie_player_playback_info.dart';

MoviePlayerPlaybackInfoSnapshot _snapshot({
  Track track = const Track(),
  VideoParams videoParams = const VideoParams(),
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
    mediaOrigin: MoviePlayerPlaybackMediaOrigin.provider,
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

  test('reports provider direct playback format and URL context', () {
    final snapshot = _snapshot(
      fileFormat: 'matroska,webm',
      originalUrl:
          'https://backend.example.com/media/1/play/movie.mkv?signature=x',
    );

    expect(snapshot.playbackSourceKindLabel, '直链 · demuxer=matroska,webm');
    expect(snapshot.playbackSourceHostLabel, 'backend.example.com');
    expect(snapshot.playbackSourceRequestPathLabel, '/media/1/play/movie.mkv');
    expect(snapshot.playbackSourceQualityLabel, isNull);
    expect(snapshot.playbackSourceDegradedHint, isNull);
  });

  test('keeps unknown format neutral', () {
    final snapshot = _snapshot();
    expect(snapshot.playbackSourceKindLabel, '--');
    expect(snapshot.playbackSourceHostLabel, isNull);
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
}
