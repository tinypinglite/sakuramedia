import 'package:flutter_test/flutter_test.dart';
import 'package:sakuramedia/features/activity/data/resource_task_record_dto.dart';

void main() {
  group('ResourceTaskRecordDto.fromJson', () {
    test('maps movie task payload with nested resource summary', () {
      final dto = ResourceTaskRecordDto.fromJson(<String, dynamic>{
        'task_key': 'movie_desc_sync',
        'resource_type': 'movie',
        'resource_id': 1234,
        'state': 'failed',
        'attempt_count': 3,
        'last_attempted_at': '2026-04-18T10:00:00Z',
        'last_succeeded_at': null,
        'last_error': 'timeout',
        'last_error_at': '2026-04-18T10:05:00Z',
        'last_task_run_id': 88,
        'last_trigger_type': 'scheduled',
        'created_at': '2026-04-01T00:00:00Z',
        'updated_at': '2026-04-18T10:05:00Z',
        'resource': <String, dynamic>{
          'resource_id': 1234,
          'movie_number': 'SSIS-123',
          'title': '示例影片',
        },
      });

      expect(dto.taskKey, 'movie_desc_sync');
      expect(dto.resourceType, 'movie');
      expect(dto.resourceId, 1234);
      expect(dto.state, 'failed');
      expect(dto.isFailed, isTrue);
      expect(dto.attemptCount, 3);
      expect(dto.lastError, 'timeout');
      expect(dto.lastTaskRunId, 88);
      expect(dto.lastTriggerType, 'scheduled');
      expect(dto.recordKey, 'movie_desc_sync/1234');
      expect(dto.resource, isNotNull);
      expect(dto.resource!.movieNumber, 'SSIS-123');
      expect(dto.resource!.title, '示例影片');
      expect(dto.resource!.path, isNull);
      expect(dto.resource!.valid, isNull);
    });

    test('maps media task payload with extra path and valid fields', () {
      final dto = ResourceTaskRecordDto.fromJson(<String, dynamic>{
        'task_key': 'media_thumbnail_generation',
        'resource_type': 'media',
        'resource_id': 42,
        'state': 'succeeded',
        'attempt_count': 1,
        'last_succeeded_at': '2026-04-18T09:00:00Z',
        'resource': <String, dynamic>{
          'resource_id': 42,
          'movie_number': 'ABC-001',
          'title': '缩略图资源',
          'path': '/mnt/media/abc-001.mp4',
          'valid': true,
        },
      });

      expect(dto.state, 'succeeded');
      expect(dto.isSucceeded, isTrue);
      expect(dto.resource, isNotNull);
      expect(dto.resource!.path, '/mnt/media/abc-001.mp4');
      expect(dto.resource!.valid, isTrue);
    });

    test('tolerates missing optional fields and null resource', () {
      final dto = ResourceTaskRecordDto.fromJson(<String, dynamic>{
        'task_key': 'movie_desc_sync',
        'resource_id': 1,
        'state': 'pending',
      });

      expect(dto.isPending, isTrue);
      expect(dto.attemptCount, 0);
      expect(dto.lastAttemptedAt, isNull);
      expect(dto.lastSucceededAt, isNull);
      expect(dto.lastError, isNull);
      expect(dto.lastTaskRunId, isNull);
      expect(dto.resource, isNull);
    });
  });
}
