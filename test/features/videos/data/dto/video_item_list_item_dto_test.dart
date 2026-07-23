import 'package:flutter_test/flutter_test.dart';
import 'package:sakuramedia/features/videos/data/dto/video_item_list_item_dto.dart';

void main() {
  group('VideoItemListItemDto.fromJson - collections 字段解析', () {
    Map<String, dynamic> baseJson() => <String, dynamic>{
          'id': 1,
          'title': 't',
          'summary': '',
          'cover_image': null,
          'release_date': null,
          'media_count': 0,
          'can_play': false,
          'created_at': '2026-01-02T03:04:05',
          'updated_at': '2026-01-02T03:04:05',
        };

    test('缺 collections 键 → 空列表', () {
      final dto = VideoItemListItemDto.fromJson(baseJson());
      expect(dto.collections, isEmpty);
    });

    test('collections 为 null / 非 List → 空列表', () {
      final withNull = baseJson()..['collections'] = null;
      expect(VideoItemListItemDto.fromJson(withNull).collections, isEmpty);

      final withScalar = baseJson()..['collections'] = 'x';
      expect(VideoItemListItemDto.fromJson(withScalar).collections, isEmpty);
    });

    test('多项合集按后端顺序保留（前端不重排）', () {
      final json = baseJson()
        ..['collections'] = <dynamic>[
          <String, dynamic>{'id': 11, 'name': 'B 系列'},
          <String, dynamic>{'id': 7, 'name': 'A 系列'},
        ];
      final refs = VideoItemListItemDto.fromJson(json).collections;
      expect(refs.map((r) => r.id).toList(), <int>[11, 7]);
      expect(refs.map((r) => r.name).toList(), <String>['B 系列', 'A 系列']);
    });

    test('非法元素（非 Map / id≤0）被跳过', () {
      final json = baseJson()
        ..['collections'] = <dynamic>[
          'not-a-map',
          <String, dynamic>{'id': 0, 'name': '无效'},
          <String, dynamic>{'id': -3, 'name': '也无效'},
          <String, dynamic>{'id': 5, 'name': '有效'},
        ];
      final refs = VideoItemListItemDto.fromJson(json).collections;
      expect(refs, hasLength(1));
      expect(refs.single.id, 5);
      expect(refs.single.name, '有效');
    });

    test('name 字段缺失时回退空串（fromJson 永不抛）', () {
      final json = baseJson()
        ..['collections'] = <dynamic>[
          <String, dynamic>{'id': 9},
        ];
      final refs = VideoItemListItemDto.fromJson(json).collections;
      expect(refs, hasLength(1));
      expect(refs.single.id, 9);
      expect(refs.single.name, '');
    });
  });
}
