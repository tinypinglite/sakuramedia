import 'package:flutter_test/flutter_test.dart';
import 'package:sakuramedia/features/activity/data/media_thumbnail_reset_result_dto.dart';

void main() {
  group('MediaThumbnailResetResultDto.fromJson', () {
    test('maps the full payload', () {
      final dto = MediaThumbnailResetResultDto.fromJson(<String, dynamic>{
        'task_key': 'media_thumbnail_generation',
        'state': 'pending',
        'reset_count': 3,
        'resource_ids': <dynamic>[10, 20, 30],
      });

      expect(dto.taskKey, 'media_thumbnail_generation');
      expect(dto.state, 'pending');
      expect(dto.resetCount, 3);
      expect(dto.resourceIds, <int>[10, 20, 30]);
      expect(dto.skippedCount, 0);
      expect(dto.skipped, isEmpty);
      expect(dto.hasSkipped, isFalse);
    });

    test('tolerates missing fields with sane defaults', () {
      final dto = MediaThumbnailResetResultDto.fromJson(
        const <String, dynamic>{},
      );

      expect(dto.taskKey, '');
      expect(dto.state, '');
      expect(dto.resetCount, 0);
      expect(dto.resourceIds, isEmpty);
      expect(dto.skippedCount, 0);
      expect(dto.skipped, isEmpty);
    });

    test('maps partial-success payload with skipped items', () {
      final dto = MediaThumbnailResetResultDto.fromJson(<String, dynamic>{
        'task_key': 'media_thumbnail_generation',
        'state': 'pending',
        'reset_count': 2,
        'resource_ids': <dynamic>[101, 102],
        'skipped_count': 2,
        'skipped': <dynamic>[
          <String, dynamic>{'resource_id': 103, 'reason': 'media_invalid'},
          <String, dynamic>{'resource_id': 104, 'reason': 'not_failed'},
        ],
      });

      expect(dto.resetCount, 2);
      expect(dto.resourceIds, <int>[101, 102]);
      expect(dto.skippedCount, 2);
      expect(dto.hasSkipped, isTrue);
      expect(dto.skippedResourceIds, <int>{103, 104});
      expect(dto.skipped.first.reason, 'media_invalid');
      expect(dto.skipped.first.reasonLabel, '媒体已失效');
      expect(dto.skipped.last.reasonLabel, '任务当前不是失败状态');
    });

    test('all-skipped payload keeps resource_ids empty', () {
      final dto = MediaThumbnailResetResultDto.fromJson(<String, dynamic>{
        'task_key': 'media_thumbnail_generation',
        'state': 'pending',
        'reset_count': 0,
        'resource_ids': <dynamic>[],
        'skipped_count': 1,
        'skipped': <dynamic>[
          <String, dynamic>{
            'resource_id': 201,
            'reason': 'task_state_not_found',
          },
        ],
      });

      expect(dto.resetCount, 0);
      expect(dto.resourceIds, isEmpty);
      expect(dto.skippedCount, 1);
      expect(dto.skipped.single.reasonLabel, '没有缩略图任务记录');
    });

    test('falls back to skipped length when skipped_count is absent', () {
      final dto = MediaThumbnailResetResultDto.fromJson(<String, dynamic>{
        'task_key': 'media_thumbnail_generation',
        'state': 'pending',
        'reset_count': 1,
        'resource_ids': <dynamic>[301],
        'skipped': <dynamic>[
          <String, dynamic>{'resource_id': 302, 'reason': 'media_not_found'},
        ],
      });

      expect(dto.skippedCount, 1);
      expect(dto.skipped.single.reasonLabel, '媒体已被删除');
    });

    test('unknown skip reason falls back to the raw value', () {
      final dto = MediaThumbnailResetResultDto.fromJson(<String, dynamic>{
        'reset_count': 0,
        'resource_ids': <dynamic>[],
        'skipped': <dynamic>[
          <String, dynamic>{'resource_id': 401, 'reason': 'brand_new_reason'},
          <String, dynamic>{'resource_id': 402},
        ],
      });

      expect(dto.skipped.first.reasonLabel, 'brand_new_reason');
      expect(dto.skipped.last.reason, '');
      expect(dto.skipped.last.reasonLabel, '未知原因');
    });

    test('ignores malformed skipped entries', () {
      final dto = MediaThumbnailResetResultDto.fromJson(<String, dynamic>{
        'reset_count': 0,
        'resource_ids': <dynamic>[],
        'skipped': <dynamic>[
          'not-a-map',
          <String, dynamic>{'resource_id': 501, 'reason': 'media_invalid'},
        ],
      });

      expect(dto.skipped, hasLength(1));
      expect(dto.skipped.single.resourceId, 501);
    });

    test('accepts numeric resource ids as double and truncates', () {
      final dto = MediaThumbnailResetResultDto.fromJson(<String, dynamic>{
        'task_key': 'media_thumbnail_generation',
        'state': 'pending',
        'reset_count': 2,
        'resource_ids': <dynamic>[10.0, 11.9, 'not-a-number'],
      });

      // 非 num 项被过滤，num 项被 toInt。
      expect(dto.resourceIds, <int>[10, 11]);
    });

    test('empty resource_ids list yields empty list', () {
      final dto = MediaThumbnailResetResultDto.fromJson(<String, dynamic>{
        'task_key': 'media_thumbnail_generation',
        'state': 'pending',
        'reset_count': 0,
        'resource_ids': <dynamic>[],
      });

      expect(dto.resourceIds, isEmpty);
    });
  });
}
