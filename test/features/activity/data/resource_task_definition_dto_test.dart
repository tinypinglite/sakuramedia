import 'package:flutter_test/flutter_test.dart';
import 'package:sakuramedia/features/activity/data/resource_task_definition_dto.dart';

void main() {
  group('ResourceTaskDefinitionDto.fromJson', () {
    test('maps all fields with full payload', () {
      final dto = ResourceTaskDefinitionDto.fromJson(<String, dynamic>{
        'task_key': 'movie_desc_sync',
        'resource_type': 'movie',
        'display_name': '影片描述回填',
        'default_sort': 'last_attempted_at:desc',
        'allow_reset': true,
        'state_counts': <String, dynamic>{
          'pending': 5,
          'running': 2,
          'succeeded': 100,
          'failed': 3,
        },
      });

      expect(dto.taskKey, 'movie_desc_sync');
      expect(dto.resourceType, 'movie');
      expect(dto.displayName, '影片描述回填');
      expect(dto.defaultSort, 'last_attempted_at:desc');
      expect(dto.allowReset, isTrue);
      expect(dto.stateCounts.pending, 5);
      expect(dto.stateCounts.running, 2);
      expect(dto.stateCounts.succeeded, 100);
      expect(dto.stateCounts.failed, 3);
      expect(dto.stateCounts.total, 110);
    });

    test('falls back to defaults when optional fields missing', () {
      final dto = ResourceTaskDefinitionDto.fromJson(const <String, dynamic>{});

      expect(dto.taskKey, '');
      expect(dto.resourceType, '');
      expect(dto.displayName, '');
      expect(dto.defaultSort, isNull);
      expect(dto.allowReset, isFalse);
      expect(dto.stateCounts, same(ResourceTaskStateCountsDto.empty));
    });

    test('tolerates partial state_counts map', () {
      final dto = ResourceTaskDefinitionDto.fromJson(<String, dynamic>{
        'task_key': 'media_thumbnail_generation',
        'state_counts': <String, dynamic>{'failed': 7},
      });

      expect(dto.stateCounts.pending, 0);
      expect(dto.stateCounts.running, 0);
      expect(dto.stateCounts.succeeded, 0);
      expect(dto.stateCounts.failed, 7);
    });

    test('treats empty default_sort string as null', () {
      final dto = ResourceTaskDefinitionDto.fromJson(<String, dynamic>{
        'task_key': 'movie_desc_sync',
        'default_sort': '   ',
      });

      expect(dto.defaultSort, isNull);
    });
  });
}
