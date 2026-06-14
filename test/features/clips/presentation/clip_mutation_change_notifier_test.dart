import 'package:flutter_test/flutter_test.dart';
import 'package:sakuramedia/features/clips/presentation/clip_mutation_change_notifier.dart';

void main() {
  test('初始无变更', () {
    final notifier = ClipMutationChangeNotifier();
    addTearDown(notifier.dispose);

    expect(notifier.lastChange, isNull);
  });

  test('reportDeleted 写入删除载荷并通知监听', () {
    final notifier = ClipMutationChangeNotifier();
    addTearDown(notifier.dispose);
    var notified = 0;
    notifier.addListener(() => notified++);

    notifier.reportDeleted(42);

    expect(notified, 1);
    final change = notifier.lastChange;
    expect(change, isNotNull);
    expect(change!.kind, ClipMutationKind.deleted);
    expect(change.clipId, 42);
    expect(change.collectionId, isNull);
  });

  test('reportCollectionMembershipChanged 写入合集载荷并通知监听', () {
    final notifier = ClipMutationChangeNotifier();
    addTearDown(notifier.dispose);
    var notified = 0;
    notifier.addListener(() => notified++);

    notifier.reportCollectionMembershipChanged(clipId: 7, collectionId: 9);

    expect(notified, 1);
    final change = notifier.lastChange;
    expect(change, isNotNull);
    expect(change!.kind, ClipMutationKind.collectionMembershipChanged);
    expect(change.clipId, 7);
    expect(change.collectionId, 9);
  });

  test('合集级变更（拖序 / 改名）允许不带 clipId', () {
    final notifier = ClipMutationChangeNotifier();
    addTearDown(notifier.dispose);

    notifier.reportCollectionMembershipChanged(collectionId: 3);

    final change = notifier.lastChange;
    expect(change!.kind, ClipMutationKind.collectionMembershipChanged);
    expect(change.clipId, isNull);
    expect(change.collectionId, 3);
  });
}
