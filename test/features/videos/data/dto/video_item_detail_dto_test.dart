import 'package:flutter_test/flutter_test.dart';
import 'package:sakuramedia/features/videos/data/dto/video_item_detail_dto.dart';
import 'package:sakuramedia/features/videos/data/dto/video_item_list_item_dto.dart';

void main() {
  Map<String, dynamic> baseJson() => <String, dynamic>{
        'id': 1,
        'title': 'detail',
        'summary': '',
        'cover_image': null,
        'release_date': null,
        'media_count': 0,
        'can_play': false,
        'created_at': '2026-01-02T03:04:05',
        'updated_at': '2026-01-02T03:04:05',
        'media_items': <dynamic>[],
      };

  group('VideoItemDetailDto.fromJson - collections 字段', () {
    test('缺 collections → 空列表', () {
      expect(VideoItemDetailDto.fromJson(baseJson()).collections, isEmpty);
    });

    test('多项合集正常解析', () {
      final json = baseJson()
        ..['collections'] = <dynamic>[
          <String, dynamic>{'id': 3, 'name': '收藏'},
          <String, dynamic>{'id': 8, 'name': '稍后再看'},
        ];
      final refs = VideoItemDetailDto.fromJson(json).collections;
      expect(refs.map((r) => r.id).toList(), <int>[3, 8]);
      expect(refs.map((r) => r.name).toList(), <String>['收藏', '稍后再看']);
    });

    test('toListItem 透传 collections', () {
      final dto = VideoItemDetailDto(
        id: 1,
        title: 't',
        mediaCount: 0,
        canPlay: false,
        collections: const <VideoCollectionRef>[
          VideoCollectionRef(id: 4, name: '合集 X'),
        ],
      );
      final listItem = dto.toListItem();
      expect(listItem.collections, hasLength(1));
      expect(listItem.collections.single.id, 4);
      expect(listItem.collections.single.name, '合集 X');
    });
  });
}
