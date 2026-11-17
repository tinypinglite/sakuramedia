import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sakuramedia/features/clips/presentation/providers/clip_mutation_events_provider.dart';

void main() {
  late ProviderContainer container;

  setUp(() {
    container = ProviderContainer();
    addTearDown(container.dispose);
  });

  test('reportDeleted 广播删除事件', () async {
    final events = <ClipMutationChange>[];
    container.listen(clipMutationEventsProvider, (_, next) {
      final change = next.value;
      if (change != null) events.add(change);
    });

    container
        .read(clipMutationEventsProvider.notifier)
        .reportDeleted(42);
    await Future<void>.delayed(Duration.zero);

    expect(events, hasLength(1));
    expect(events.single.kind, ClipMutationKind.deleted);
    expect(events.single.clipId, 42);
    expect(events.single.collectionId, isNull);
  });

  test('reportCollectionMembershipChanged 广播合集变更事件（含 clipId）', () async {
    final events = <ClipMutationChange>[];
    container.listen(clipMutationEventsProvider, (_, next) {
      final change = next.value;
      if (change != null) events.add(change);
    });

    container
        .read(clipMutationEventsProvider.notifier)
        .reportCollectionMembershipChanged(clipId: 7, collectionId: 9);
    await Future<void>.delayed(Duration.zero);

    expect(events, hasLength(1));
    expect(events.single.kind, ClipMutationKind.collectionMembershipChanged);
    expect(events.single.clipId, 7);
    expect(events.single.collectionId, 9);
  });

  test('合集级变更（拖序 / 改名）允许不带 clipId', () async {
    final events = <ClipMutationChange>[];
    container.listen(clipMutationEventsProvider, (_, next) {
      final change = next.value;
      if (change != null) events.add(change);
    });

    container
        .read(clipMutationEventsProvider.notifier)
        .reportCollectionMembershipChanged(collectionId: 3);
    await Future<void>.delayed(Duration.zero);

    expect(events, hasLength(1));
    expect(events.single.clipId, isNull);
    expect(events.single.collectionId, 3);
  });
}
