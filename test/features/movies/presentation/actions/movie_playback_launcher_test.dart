import 'package:flutter_test/flutter_test.dart';
import 'package:sakuramedia/features/movies/data/dto/detail/movie_detail_dto.dart';

MovieMediaItemDto _media({
  int mediaId = 1,
  String playUrl = '/media/1/play/file.mp4?expires=1&signature=sig',
}) {
  return MovieMediaItemDto(
    mediaId: mediaId,
    libraryId: 1,
    providerKey: 'filesystem',
    playUrl: playUrl,
    fileName: 'movie.mp4',
    resolution: '1920x1080',
    fileSizeBytes: 100,
    durationSeconds: 60,
    valid: true,
    progress: null,
    points: const <MovieMediaPointDto>[],
  );
}

void main() {
  test('parses the provider playback contract without storage fields', () {
    final dto = MovieMediaItemDto.fromJson(<String, dynamic>{
      'media_id': 12,
      'library_id': 3,
      'provider_key': 's3',
      'play_url': '/media/12/play/movie.mkv?expires=1&signature=sig',
      'file_name': 'movie.mkv',
      'resolution': null,
      'file_size_bytes': 100,
      'duration_seconds': 10,
      'valid': true,
      'progress': null,
      'points': <Map<String, dynamic>>[],
    });

    expect(dto.mediaId, 12);
    expect(dto.providerKey, 's3');
    expect(dto.fileName, 'movie.mkv');
    expect(dto.playUrl, contains('/media/12/play/'));
    expect(dto.resolution, isNull);
    expect(dto.hasPlayableUrl, isTrue);
  });

  test('copyWith preserves signed play URL and provider metadata', () {
    final media = _media();
    final copy = media.copyWith(points: const <MovieMediaPointDto>[]);

    expect(copy.playUrl, media.playUrl);
    expect(copy.providerKey, media.providerKey);
    expect(copy.fileName, media.fileName);
    expect(copy.libraryId, media.libraryId);
    expect(copy.points, isEmpty);
  });

  test('nullable fields can be cleared independently', () {
    final media = _media();
    final withProgress = media.copyWith(
      progress: const MovieMediaProgressDto(
        lastPositionSeconds: 120,
        lastWatchedAt: null,
      ),
    );

    expect(withProgress.copyWith().progress, isNotNull);
    expect(withProgress.copyWith(progress: null).progress, isNull);
    expect(withProgress.copyWith(providerKey: null).providerKey, isNull);
    expect(withProgress.copyWith(resolution: null).resolution, isNull);
  });
}
