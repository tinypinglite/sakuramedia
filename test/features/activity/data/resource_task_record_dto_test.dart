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

  group('ResourceTaskRecordDto.canBatchReset', () {
    ResourceTaskRecordDto build({
      required String state,
      bool hasResource = true,
      bool? valid,
    }) {
      return ResourceTaskRecordDto.fromJson(<String, dynamic>{
        'task_key': 'media_thumbnail_generation',
        'resource_type': 'media',
        'resource_id': 7,
        'state': state,
        'resource':
            hasResource
                ? <String, dynamic>{
                  'resource_id': 7,
                  if (valid != null) 'valid': valid,
                }
                : null,
      });
    }

    test('failed + 媒体存在且有效 → 可重置，无媒体不可用标签', () {
      final dto = build(state: 'failed', valid: true);
      expect(dto.canBatchReset, isTrue);
      expect(dto.mediaUnavailableLabel, isNull);
    });

    test('valid 未下发时按未知处理，不拦截', () {
      final dto = build(state: 'failed');
      expect(dto.canBatchReset, isTrue);
      expect(dto.mediaUnavailableLabel, isNull);
    });

    test('非 failed 状态不可重置，但媒体正常时不挂标签', () {
      for (final state in <String>['pending', 'succeeded', 'running']) {
        final dto = build(state: state, valid: true);
        expect(dto.canBatchReset, isFalse, reason: state);
        // 用户没打算重置一条 pending/succeeded 任务，别自作聪明挂"不可重置"。
        expect(dto.mediaUnavailableLabel, isNull, reason: state);
      }
    });

    test('媒体失效不可重置，标签常驻', () {
      final dto = build(state: 'failed', valid: false);
      expect(dto.canBatchReset, isFalse);
      expect(dto.mediaUnavailableLabel, '媒体已失效');
    });

    test('媒体已删除（resource 为 null）不可重置，标签常驻', () {
      final dto = build(state: 'failed', hasResource: false);
      expect(dto.canBatchReset, isFalse);
      expect(dto.mediaUnavailableLabel, '媒体已删除');
    });

    test('媒体不可用与任务状态无关：非 failed 也挂标签', () {
      // 用户浏览成功列表时，也能看到"其实媒体已经没了"，方便理解现状。
      expect(
        build(state: 'succeeded', valid: false).mediaUnavailableLabel,
        '媒体已失效',
      );
      expect(
        build(state: 'pending', hasResource: false).mediaUnavailableLabel,
        '媒体已删除',
      );
    });
  });
}
