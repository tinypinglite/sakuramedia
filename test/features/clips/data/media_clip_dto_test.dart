import 'package:flutter_test/flutter_test.dart';
import 'package:sakuramedia/features/clips/data/media_clip_dto.dart';

void main() {
  group('MediaClipDto.fromJson', () {
    test('maps all fields with full payload', () {
      final dto = MediaClipDto.fromJson(<String, dynamic>{
        'clip_id': 12,
        'media_id': 34,
        'movie_number': 'ABC-001',
        'start_offset_seconds': 10,
        'end_offset_seconds': 30,
        'title': '精彩片段',
        'duration_seconds': 20,
        'file_size_bytes': 1048576,
        'cover_image': <String, dynamic>{
          'id': 1,
          'origin': '/clips/12-origin.webp',
          'small': '/clips/12-small.webp',
          'medium': '/clips/12-medium.webp',
          'large': '/clips/12-large.webp',
        },
        'stream_url': '/media-clips/12/stream?expires=1&signature=abc',
        'created_at': '2026-06-13T10:00:00Z',
      });

      expect(dto.clipId, 12);
      expect(dto.mediaId, 34);
      expect(dto.movieNumber, 'ABC-001');
      expect(dto.startOffsetSeconds, 10);
      expect(dto.endOffsetSeconds, 30);
      expect(dto.title, '精彩片段');
      expect(dto.durationSeconds, 20);
      expect(dto.fileSizeBytes, 1048576);
      expect(dto.coverImage?.bestAvailableUrl, '/clips/12-large.webp');
      expect(dto.streamUrl, '/media-clips/12/stream?expires=1&signature=abc');
      expect(dto.createdAt, DateTime.parse('2026-06-13T10:00:00Z'));
    });

    test('falls back to defaults when fields missing', () {
      final dto = MediaClipDto.fromJson(const <String, dynamic>{});

      expect(dto.clipId, 0);
      expect(dto.mediaId, isNull);
      expect(dto.movieNumber, isNull);
      expect(dto.startOffsetSeconds, 0);
      expect(dto.endOffsetSeconds, 0);
      expect(dto.title, '');
      expect(dto.durationSeconds, 0);
      expect(dto.fileSizeBytes, 0);
      expect(dto.coverImage, isNull);
      expect(dto.streamUrl, '');
      expect(dto.createdAt, isNull);
    });

    test('tolerates null media/cover after source removal', () {
      final dto = MediaClipDto.fromJson(<String, dynamic>{
        'clip_id': 7,
        'media_id': null,
        'movie_number': 'ABC-001',
        'start_offset_seconds': 0,
        'end_offset_seconds': 15,
        'title': '',
        'duration_seconds': 15,
        'file_size_bytes': 2048,
        'cover_image': null,
        'stream_url': '/media-clips/7/stream?expires=2&signature=z',
        'created_at': '',
      });

      expect(dto.clipId, 7);
      expect(dto.mediaId, isNull);
      expect(dto.coverImage, isNull);
      expect(dto.createdAt, isNull);
      expect(dto.streamUrl, '/media-clips/7/stream?expires=2&signature=z');
    });
  });
}
