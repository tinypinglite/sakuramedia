import 'package:flutter_test/flutter_test.dart';
import 'package:sakuramedia/features/movies/data/dto/detail/movie_detail_dto.dart';
import 'package:sakuramedia/features/movies/presentation/actions/movie_playback_launcher.dart';

MovieMediaItemDto _media({
  required int mediaId,
  required String playUrl,
  String? libraryBackend,
}) {
  return MovieMediaItemDto(
    mediaId: mediaId,
    libraryId: 1,
    libraryBackend: libraryBackend,
    playUrl: playUrl,
    storageMode: '',
    resolution: '3840x1920',
    fileSizeBytes: 0,
    durationSeconds: 0,
    specialTags: '',
    valid: true,
    progress: null,
    points: const <MovieMediaPointDto>[],
  );
}

void main() {
  group('resolveExternalPlayerSingleUrl', () {
    test(
      'cloud115 media switches /stream to /stream.m3u8 keeping signature',
      () {
        final media = _media(
          mediaId: 5453,
          libraryBackend: 'cloud115',
          playUrl:
              '/media/5453/stream?expires=1785628800&signature=145bddc07079',
        );

        expect(media.isCloud115, isTrue);
        expect(
          resolveExternalPlayerSingleUrl(media),
          '/media/5453/stream.m3u8?expires=1785628800&signature=145bddc07079',
        );
      },
    );

    test('local media keeps the /stream byte stream url', () {
      final media = _media(
        mediaId: 100,
        libraryBackend: 'local',
        playUrl: '/media/100/stream?expires=1&signature=sig',
      );

      expect(media.isCloud115, isFalse);
      expect(resolveExternalPlayerSingleUrl(media), media.playUrl);
    });

    test('unknown backend (orphan media) keeps /stream url', () {
      final media = _media(
        mediaId: 101,
        libraryBackend: null,
        playUrl: '/media/101/stream?expires=1&signature=sig',
      );

      expect(resolveExternalPlayerSingleUrl(media), media.playUrl);
    });
  });

  group('MovieMediaItemDto.isCloud115', () {
    test('parses library_backend cloud115', () {
      final dto = MovieMediaItemDto.fromJson(<String, dynamic>{
        'media_id': 1,
        'library_id': 3,
        'library_backend': 'cloud115',
        'play_url': '/media/1/stream?expires=1&signature=sig',
        'storage_mode': 'rapid_upload',
        'resolution': '4096x2048',
        'file_size_bytes': 100,
        'duration_seconds': 10,
        'special_tags': '',
        'valid': true,
        'progress': null,
        'points': <Map<String, dynamic>>[],
      });
      expect(dto.isCloud115, isTrue);
    });

    test('parses library_backend local', () {
      final dto = MovieMediaItemDto.fromJson(<String, dynamic>{
        'media_id': 1,
        'library_id': 1,
        'library_backend': 'local',
        'play_url': '/media/1/stream?expires=1&signature=sig',
        'storage_mode': 'local',
        'resolution': '1920x1080',
        'file_size_bytes': 100,
        'duration_seconds': 10,
        'special_tags': '',
        'valid': true,
        'progress': null,
        'points': <Map<String, dynamic>>[],
      });
      expect(dto.isCloud115, isFalse);
    });
  });

  group('MovieMediaItemDto.copyWith', () {
    final media = _media(
      mediaId: 5453,
      libraryBackend: 'cloud115',
      playUrl: '/media/5453/stream?expires=1&signature=sig',
    );

    test('replaces points and keeps other fields', () {
      final updated = media.copyWith(points: const <MovieMediaPointDto>[]);

      expect(updated.points, isEmpty);
      expect(updated.mediaId, media.mediaId);
      expect(updated.libraryBackend, media.libraryBackend);
      expect(updated.playUrl, media.playUrl);
      expect(updated.isCloud115, isTrue);
    });

    test('no-arg copyWith is equivalent', () {
      final copy = media.copyWith();

      expect(copy.mediaId, media.mediaId);
      expect(copy.libraryId, media.libraryId);
      expect(copy.libraryBackend, media.libraryBackend);
      expect(copy.playUrl, media.playUrl);
      expect(copy.storageMode, media.storageMode);
      expect(copy.resolution, media.resolution);
      expect(copy.fileSizeBytes, media.fileSizeBytes);
      expect(copy.durationSeconds, media.durationSeconds);
      expect(copy.specialTags, media.specialTags);
      expect(copy.valid, media.valid);
      expect(copy.progress, media.progress);
      expect(copy.points, media.points);
      expect(copy.videoInfo, media.videoInfo);
    });

    test('nullable sentinel distinguishes keep from clear', () {
      final withProgress = _media(
        mediaId: 1,
        libraryBackend: 'cloud115',
        playUrl: '/media/1/stream?expires=1&signature=sig',
      );
      final progressed = MovieMediaItemDto(
        mediaId: withProgress.mediaId,
        libraryId: withProgress.libraryId,
        libraryBackend: withProgress.libraryBackend,
        playUrl: withProgress.playUrl,
        storageMode: withProgress.storageMode,
        resolution: withProgress.resolution,
        fileSizeBytes: withProgress.fileSizeBytes,
        durationSeconds: withProgress.durationSeconds,
        specialTags: withProgress.specialTags,
        valid: withProgress.valid,
        progress: const MovieMediaProgressDto(
          lastPositionSeconds: 120,
          lastWatchedAt: null,
        ),
        points: withProgress.points,
        videoInfo: withProgress.videoInfo,
      );

      expect(progressed.copyWith().progress, isNotNull);
      expect(progressed.copyWith(progress: null).progress, isNull);
      expect(progressed.copyWith(libraryBackend: null).libraryBackend, isNull);
    });
  });
}
