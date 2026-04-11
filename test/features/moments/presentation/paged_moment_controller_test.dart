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
        fetchPage: (page, pageSize, sort) async {
          cycle += 1;
          expect(sort, MomentSortOrder.latest.apiValue);
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
        fetchPage: (page, pageSize, sort) async {
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
  });
}

MediaPointListItemDto _moment(int pointId) {
  return MediaPointListItemDto(
    pointId: pointId,
    mediaId: 100,
    movieNumber: 'ABC-001',
    thumbnailId: 10 + pointId,
    offsetSeconds: 120,
    image: null,
    createdAt: DateTime.parse('2026-03-12T10:00:00Z'),
  );
}
