import 'package:flutter_test/flutter_test.dart';
import 'package:sakuramedia/features/media/data/media_list_item_dto.dart';

void main() {
  test('MediaListItemDto parses media file tags and manual lock', () {
    final item = MediaListItemDto.fromJson(<String, dynamic>{
      'id': 12,
      'kind': 'jav',
      'movie_number': 'ABC-001',
      'file_name': 'ABC-001.4k.mkv',
      'file_size_bytes': 1024,
      'duration_seconds': 60,
      'valid': true,
      'tags': [
        {'id': 1, 'name': '4K'},
      ],
      'is_media_tags_manually_managed': true,
      'created_at': '2026-10-31T01:02:03Z',
      'updated_at': '2026-10-31T01:02:03Z',
    });

    expect(item.tags.single.id, 1);
    expect(item.tags.single.name, '4K');
    expect(item.isMediaTagsManuallyManaged, isTrue);
  });
}
