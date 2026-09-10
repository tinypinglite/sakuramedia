import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:sakuramedia/features/moment_collections/data/dto/moment_collection_dto.dart';
import 'package:sakuramedia/features/moment_collections/presentation/providers/moment_collections_api_provider.dart';
import 'package:sakuramedia/features/shared/presentation/providers/async_notifier_dispose_guard.dart';

part 'moment_collections_overview_provider.g.dart';

@Riverpod(retry: kNoAsyncNotifierRetry)
class MomentCollectionsOverview extends _$MomentCollectionsOverview
    with AsyncNotifierDisposeGuardMixin<List<MomentCollectionDto>> {
  @override
  Future<List<MomentCollectionDto>> build() async {
    attachDisposeGuard();
    return ref.read(momentCollectionsApiProvider).getCollections();
  }

  Future<void> refresh() async {
    try {
      final next = await ref
          .read(momentCollectionsApiProvider)
          .getCollections();
      if (!isDisposed) state = AsyncData(next);
    } catch (error, stack) {
      if (!isDisposed) state = AsyncError(error, stack);
    }
  }

  void insertCollection(MomentCollectionDto collection) {
    final current = state.value;
    if (current != null) {
      state = AsyncData(<MomentCollectionDto>[collection, ...current]);
    }
  }

  void replaceCollection(MomentCollectionDto collection) {
    final current = state.value;
    if (current == null) return;
    state = AsyncData([
      for (final item in current)
        if (item.id == collection.id) collection else item,
    ]);
  }

  void removeCollection(int collectionId) {
    final current = state.value;
    if (current != null) {
      state = AsyncData(
        current
            .where((item) => item.id != collectionId)
            .toList(growable: false),
      );
    }
  }
}
