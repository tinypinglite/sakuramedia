import 'package:flutter_test/flutter_test.dart';
import 'package:sakuramedia/core/network/paginated_response_dto.dart';
import 'package:sakuramedia/features/clips/data/dto/media_clip_dto.dart';
import 'package:sakuramedia/features/clips/presentation/clips_overview_controller.dart';

MediaClipDto _clip(int id, {String title = ''}) => MediaClipDto(
  clipId: id,
  mediaId: 1,
  movieNumber: 'ABC-001',
  startOffsetSeconds: 0,
  endOffsetSeconds: 10,
  title: title,
  durationSeconds: 10,
  fileSizeBytes: 1024,
  coverImage: null,
  streamUrl: '/media-clips/$id/stream',
  createdAt: null,
);

PaginatedResponseDto<MediaClipDto> _page(
  List<MediaClipDto> items, {
  required int page,
  required int total,
  int pageSize = 2,
}) => PaginatedResponseDto<MediaClipDto>(
  items: items,
  page: page,
  pageSize: pageSize,
  total: total,
);

void main() {
  test('load populates first page and tracks hasMore', () async {
    final controller = ClipsOverviewController(
      pageSize: 2,
      fetchClips:
          ({int page = 1, int pageSize = 2, String sort = 'created_at:desc'}) async =>
              _page([_clip(1), _clip(2)], page: 1, total: 3),
    );
    addTearDown(controller.dispose);

    await controller.load();

    expect(controller.isLoading, isFalse);
    expect(controller.clips, hasLength(2));
    expect(controller.hasMore, isTrue);
    expect(controller.errorMessage, isNull);
  });

  test('loadMore appends next page and clears hasMore at the end', () async {
    final controller = ClipsOverviewController(
      pageSize: 2,
      fetchClips: ({int page = 1, int pageSize = 2, String sort = 'created_at:desc'}) async {
        if (page == 1) {
          return _page([_clip(1), _clip(2)], page: 1, total: 3);
        }
        return _page([_clip(3)], page: 2, total: 3);
      },
    );
    addTearDown(controller.dispose);

    await controller.load();
    await controller.loadMore();

    expect(controller.clips.map((c) => c.clipId), <int>[1, 2, 3]);
    expect(controller.hasMore, isFalse);
  });

  test('loadMore records error and keeps existing items', () async {
    var calls = 0;
    final controller = ClipsOverviewController(
      pageSize: 2,
      fetchClips: ({int page = 1, int pageSize = 2, String sort = 'created_at:desc'}) async {
        calls++;
        if (calls == 1) {
          return _page([_clip(1), _clip(2)], page: 1, total: 5);
        }
        throw Exception('network down');
      },
    );
    addTearDown(controller.dispose);

    await controller.load();
    await controller.loadMore();

    expect(controller.clips, hasLength(2));
    expect(controller.loadMoreErrorMessage, isNotNull);
  });

  test('removeClip drops the clip and decrements total', () async {
    final controller = ClipsOverviewController(
      pageSize: 2,
      fetchClips:
          ({int page = 1, int pageSize = 2, String sort = 'created_at:desc'}) async =>
              _page([_clip(1), _clip(2)], page: 1, total: 2),
    );
    addTearDown(controller.dispose);

    await controller.load();
    controller.removeClip(1);

    expect(controller.clips.map((c) => c.clipId), <int>[2]);
    expect(controller.hasMore, isFalse);
  });

  test('replaceClip swaps the matching clip in place', () async {
    final controller = ClipsOverviewController(
      pageSize: 2,
      fetchClips:
          ({int page = 1, int pageSize = 2, String sort = 'created_at:desc'}) async =>
              _page([_clip(1, title: 'old'), _clip(2)], page: 1, total: 2),
    );
    addTearDown(controller.dispose);

    await controller.load();
    controller.replaceClip(_clip(1, title: 'new'));

    expect(controller.clips.first.title, 'new');
    expect(controller.clips, hasLength(2));
  });

  test('setSort reloads first page with the new sort expression', () async {
    final sorts = <String>[];
    final controller = ClipsOverviewController(
      pageSize: 2,
      fetchClips: ({
        int page = 1,
        int pageSize = 2,
        String sort = 'created_at:desc',
      }) async {
        sorts.add(sort);
        return _page([_clip(1), _clip(2)], page: 1, total: 2);
      },
    );
    addTearDown(controller.dispose);

    await controller.load();
    await controller.setSort('created_at:asc');

    expect(controller.sort, 'created_at:asc');
    expect(sorts, <String>['created_at:desc', 'created_at:asc']);
  });

  test('setSort with the current sort does not refetch', () async {
    var calls = 0;
    final controller = ClipsOverviewController(
      pageSize: 2,
      fetchClips: ({
        int page = 1,
        int pageSize = 2,
        String sort = 'created_at:desc',
      }) async {
        calls++;
        return _page([_clip(1)], page: 1, total: 1);
      },
    );
    addTearDown(controller.dispose);

    await controller.load();
    await controller.setSort('created_at:desc');

    expect(calls, 1);
  });
}
