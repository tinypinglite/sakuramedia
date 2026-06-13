import 'package:flutter_test/flutter_test.dart';
import 'package:sakuramedia/features/clip_collections/data/clip_collection_dto.dart';
import 'package:sakuramedia/features/clip_collections/presentation/clip_collections_overview_controller.dart';

ClipCollectionDto _collection(int id, {String name = ''}) => ClipCollectionDto(
  id: id,
  name: name.isEmpty ? '合集$id' : name,
  description: '',
  clipCount: 0,
  coverImage: null,
  createdAt: null,
  updatedAt: null,
);

void main() {
  test('load populates collections', () async {
    final controller = ClipCollectionsOverviewController(
      fetchCollections: () async => [_collection(1), _collection(2)],
    );
    addTearDown(controller.dispose);

    await controller.load();

    expect(controller.isLoading, isFalse);
    expect(controller.errorMessage, isNull);
    expect(controller.collections, hasLength(2));
    expect(controller.isEmpty, isFalse);
  });

  test('load surfaces error and clears list', () async {
    final controller = ClipCollectionsOverviewController(
      fetchCollections: () async => throw Exception('boom'),
    );
    addTearDown(controller.dispose);

    await controller.load();

    expect(controller.errorMessage, isNotNull);
    expect(controller.collections, isEmpty);
  });

  test('isEmpty true only when loaded without error and no items', () async {
    final controller = ClipCollectionsOverviewController(
      fetchCollections: () async => const <ClipCollectionDto>[],
    );
    addTearDown(controller.dispose);

    await controller.load();

    expect(controller.isEmpty, isTrue);
  });

  test('insertCollection prepends', () async {
    final controller = ClipCollectionsOverviewController(
      fetchCollections: () async => [_collection(1)],
    );
    addTearDown(controller.dispose);
    await controller.load();

    controller.insertCollection(_collection(2, name: '新合集'));

    expect(controller.collections.first.id, 2);
    expect(controller.collections, hasLength(2));
  });

  test('replaceCollection updates matching id', () async {
    final controller = ClipCollectionsOverviewController(
      fetchCollections: () async => [_collection(1, name: '旧')],
    );
    addTearDown(controller.dispose);
    await controller.load();

    controller.replaceCollection(_collection(1, name: '新'));

    expect(controller.collections.single.name, '新');
  });

  test('removeCollection drops matching id', () async {
    final controller = ClipCollectionsOverviewController(
      fetchCollections: () async => [_collection(1), _collection(2)],
    );
    addTearDown(controller.dispose);
    await controller.load();

    controller.removeCollection(1);

    expect(controller.collections.single.id, 2);
  });
}
