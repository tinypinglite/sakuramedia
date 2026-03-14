import 'package:flutter_test/flutter_test.dart';
import 'package:sakuramedia/features/movies/data/movie_list_item_dto.dart';
import 'package:sakuramedia/features/movies/data/movie_media_thumbnail_dto.dart';
import 'package:sakuramedia/features/movies/presentation/movie_detail_thumbnail_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late List<int> requestedMediaIds;

  setUp(() {
    requestedMediaIds = <int>[];
  });

  test('loadIfNeeded fetches thumbnails once for the selected media', () async {
    final controller = MovieDetailThumbnailController(
      mediaId: 100,
      fetchMediaThumbnails: ({required mediaId}) async {
        requestedMediaIds.add(mediaId);
        return _thumbnails(mediaId: mediaId);
      },
    );
    addTearDown(controller.dispose);

    await controller.loadIfNeeded();
    await controller.loadIfNeeded();

    expect(requestedMediaIds, <int>[100]);
    expect(controller.thumbnails, hasLength(2));
    expect(controller.hasLoaded, isTrue);
    expect(controller.activeIndex, 0);
  });

  test('loadIfNeeded stays idle when there is no selected media', () async {
    final controller = MovieDetailThumbnailController(
      mediaId: null,
      fetchMediaThumbnails: ({required mediaId}) async {
        requestedMediaIds.add(mediaId);
        return _thumbnails(mediaId: mediaId);
      },
    );
    addTearDown(controller.dispose);

    await controller.loadIfNeeded();

    expect(requestedMediaIds, isEmpty);
    expect(controller.thumbnails, isEmpty);
    expect(controller.hasLoaded, isTrue);
    expect(controller.errorMessage, isNull);
  });

  test('retry re-requests thumbnails after a failed load', () async {
    var attempt = 0;
    final controller = MovieDetailThumbnailController(
      mediaId: 100,
      fetchMediaThumbnails: ({required mediaId}) async {
        attempt += 1;
        requestedMediaIds.add(mediaId);
        if (attempt == 1) {
          throw Exception('boom');
        }
        return _thumbnails(mediaId: mediaId);
      },
    );
    addTearDown(controller.dispose);

    await controller.loadIfNeeded();

    expect(controller.errorMessage, isNotNull);
    expect(controller.thumbnails, isEmpty);

    await controller.retry();

    expect(requestedMediaIds, <int>[100, 100]);
    expect(controller.errorMessage, isNull);
    expect(controller.thumbnails, hasLength(2));
  });

  test('selectIndex updates active thumbnail only for valid indices', () async {
    final controller = MovieDetailThumbnailController(
      mediaId: 100,
      fetchMediaThumbnails:
          ({required mediaId}) async => _thumbnails(mediaId: mediaId),
    );
    addTearDown(controller.dispose);
    await controller.loadIfNeeded();

    controller.selectIndex(1);
    expect(controller.activeIndex, 1);

    controller.selectIndex(99);
    expect(controller.activeIndex, 1);
  });

  test('columns use auto value until user overrides manually', () {
    final controller = MovieDetailThumbnailController(
      mediaId: 100,
      fetchMediaThumbnails:
          ({required mediaId}) async => _thumbnails(mediaId: mediaId),
    );
    addTearDown(controller.dispose);

    expect(controller.columns, isNull);

    controller.applyAutoColumns(5);
    expect(controller.columns, 5);

    controller.setColumns(3);
    expect(controller.columns, 3);

    controller.applyAutoColumns(4);
    expect(controller.columns, 3);
  });
}

List<MovieMediaThumbnailDto> _thumbnails({required int mediaId}) {
  return <MovieMediaThumbnailDto>[
    MovieMediaThumbnailDto(
      thumbnailId: 1,
      mediaId: mediaId,
      offsetSeconds: 10,
      image: const MovieImageDto(
        id: 1,
        origin: 'thumb-1.webp',
        small: 'thumb-1.webp',
        medium: 'thumb-1.webp',
        large: 'thumb-1.webp',
      ),
    ),
    MovieMediaThumbnailDto(
      thumbnailId: 2,
      mediaId: mediaId,
      offsetSeconds: 20,
      image: const MovieImageDto(
        id: 2,
        origin: 'thumb-2.webp',
        small: 'thumb-2.webp',
        medium: 'thumb-2.webp',
        large: 'thumb-2.webp',
      ),
    ),
  ];
}
