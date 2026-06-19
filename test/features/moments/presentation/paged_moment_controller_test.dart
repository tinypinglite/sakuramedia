import 'package:flutter_test/flutter_test.dart';
import 'package:sakuramedia/core/network/paginated_response_dto.dart';
import 'package:sakuramedia/features/media/data/media_point_list_item_dto.dart';
import 'package:sakuramedia/features/moments/presentation/paged_moment_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PagedMomentController', () {
    test('refresh replaces first page items', () async {
      var cycle = 0;
      final controller = PagedMomentController(
        fetchPage: (page, pageSize, sort, kind) async {
          cycle += 1;
          expect(sort, MomentSortOrder.latest.apiValue);
          expect(kind, MomentKindFilter.jav.apiValue);
          if (cycle == 1) {
            return PaginatedResponseDto<MediaPointListItemDto>(
              items: <MediaPointListItemDto>[_moment(1)],
              page: 1,
              pageSize: 20,
              total: 2,
            );
          }
          return PaginatedResponseDto<MediaPointListItemDto>(
            items: <MediaPointListItemDto>[_moment(99)],
            page: 1,
            pageSize: 20,
            total: 1,
          );
        },
      );

      await controller.initialize();
      await controller.refresh();

      expect(controller.items.single.pointId, 99);
      expect(controller.currentPage, 1);
      expect(controller.total, 1);
      expect(controller.hasMore, isFalse);

      controller.dispose();
    });

    test('refresh rethrows and keeps existing items on failure', () async {
      var cycle = 0;
      final controller = PagedMomentController(
        fetchPage: (page, pageSize, sort, kind) async {
          cycle += 1;
          if (cycle == 1) {
            return PaginatedResponseDto<MediaPointListItemDto>(
              items: <MediaPointListItemDto>[_moment(1)],
              page: 1,
              pageSize: 20,
              total: 2,
            );
          }
          throw Exception('refresh failed');
        },
      );

      await controller.initialize();

      await expectLater(controller.refresh(), throwsException);

      expect(controller.items.single.pointId, 1);
      expect(controller.currentPage, 1);
      expect(controller.total, 2);

      controller.dispose();
    });

    test('setKindFilter reloads with the new kind apiValue', () async {
      final kindCalls = <String>[];
      var cycle = 0;
      final controller = PagedMomentController(
        fetchPage: (page, pageSize, sort, kind) async {
          kindCalls.add(kind);
          cycle += 1;
          return PaginatedResponseDto<MediaPointListItemDto>(
            items: <MediaPointListItemDto>[
              if (cycle == 1) _moment(1) else _moment(2, videoItemId: 42),
            ],
            page: 1,
            pageSize: 20,
            total: 1,
          );
        },
      );

      await controller.initialize();
      expect(controller.kindFilter, MomentKindFilter.jav);

      await controller.setKindFilter(MomentKindFilter.video);

      expect(kindCalls, <String>['jav', 'video']);
      expect(controller.kindFilter, MomentKindFilter.video);
      expect(controller.items.single.isVideo, isTrue);

      // 相等短路：不会发起新请求。
      await controller.setKindFilter(MomentKindFilter.video);
      expect(kindCalls, <String>['jav', 'video']);

      controller.dispose();
    });
  });
}

MediaPointListItemDto _moment(int pointId, {int? videoItemId}) {
  return MediaPointListItemDto(
    pointId: pointId,
    mediaId: 100,
    movieNumber: videoItemId == null ? 'ABC-001' : null,
    videoItemId: videoItemId,
    thumbnailId: 10 + pointId,
    offsetSeconds: 120,
    image: null,
    createdAt: DateTime.parse('2026-03-12T10:00:00Z'),
  );
}
