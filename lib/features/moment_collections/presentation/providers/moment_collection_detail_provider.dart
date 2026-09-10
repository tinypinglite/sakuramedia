import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:sakuramedia/features/moment_collections/data/dto/moment_collection_dto.dart';
import 'package:sakuramedia/features/moment_collections/presentation/providers/moment_collections_api_provider.dart';
import 'package:sakuramedia/features/shared/presentation/providers/async_notifier_dispose_guard.dart';
import 'package:sakuramedia/features/shared/presentation/providers/optimistic_patch_mixin.dart';

part 'moment_collection_detail_provider.g.dart';

class MomentCollectionDetailState {
  const MomentCollectionDetailState({
    required this.collection,
    required this.points,
  });

  final MomentCollectionDto collection;
  final List<MomentCollectionPointDto> points;

  MomentCollectionDetailState copyWith({
    MomentCollectionDto? collection,
    List<MomentCollectionPointDto>? points,
  }) => MomentCollectionDetailState(
    collection: collection ?? this.collection,
    points: points ?? this.points,
  );
}

@riverpod
class MomentCollectionDetail extends _$MomentCollectionDetail
    with
        AsyncNotifierDisposeGuardMixin<MomentCollectionDetailState>,
        OptimisticPatchMixin<MomentCollectionDetailState> {
  static const Object _mutationKey = #momentCollectionDetailMutation;

  @override
  bool get isOptimisticPatchDisposed => isDisposed;

  bool get isMutating => isInFlight(_mutationKey);

  @override
  Future<MomentCollectionDetailState> build(int collectionId) async {
    attachDisposeGuard();
    final api = ref.read(momentCollectionsApiProvider);
    final results = await Future.wait<Object>([
      api.getCollection(collectionId: collectionId),
      api.getAllCollectionPoints(collectionId: collectionId),
    ]);
    return MomentCollectionDetailState(
      collection: results[0] as MomentCollectionDto,
      points: results[1] as List<MomentCollectionPointDto>,
    );
  }

  Future<void> refresh() async {
    final api = ref.read(momentCollectionsApiProvider);
    try {
      final results = await Future.wait<Object>([
        api.getCollection(collectionId: collectionId),
        api.getAllCollectionPoints(collectionId: collectionId),
      ]);
      if (!isDisposed) {
        state = AsyncData(
          MomentCollectionDetailState(
            collection: results[0] as MomentCollectionDto,
            points: results[1] as List<MomentCollectionPointDto>,
          ),
        );
      }
    } catch (error, stack) {
      if (!isDisposed) state = AsyncError(error, stack);
    }
  }

  Future<void> removePoint(int pointId) async {
    if (state.value == null) return;
    await withOptimisticPatch<void>(
      key: _mutationKey,
      apply: (current) => _dropPoint(current, pointId),
      action: () => ref
          .read(momentCollectionsApiProvider)
          .removePoint(collectionId: collectionId, pointId: pointId),
    );
  }

  Future<void> reorder(int oldIndex, int newIndex) async {
    final current = state.value;
    if (current == null || oldIndex == newIndex) return;
    await withOptimisticPatch<void>(
      key: _mutationKey,
      apply: (current) => _reorderPoints(current, oldIndex, newIndex),
      action: () async {
        final points =
            state.value?.points ?? const <MomentCollectionPointDto>[];
        await ref
            .read(momentCollectionsApiProvider)
            .setPoints(
              collectionId: collectionId,
              pointIds: points
                  .map((point) => point.pointId)
                  .toList(growable: false),
            );
      },
    );
  }

  void replaceCollection(MomentCollectionDto collection) {
    final current = state.value;
    if (current != null) {
      state = AsyncData(current.copyWith(collection: collection));
    }
  }

  MomentCollectionDetailState _dropPoint(
    MomentCollectionDetailState current,
    int pointId,
  ) {
    final points = current.points
        .where((point) => point.pointId != pointId)
        .toList(growable: false);
    if (points.length == current.points.length) return current;
    return current.copyWith(
      collection: MomentCollectionDto(
        id: current.collection.id,
        name: current.collection.name,
        description: current.collection.description,
        pointCount: points.length,
        coverImage: current.collection.coverImage,
        createdAt: current.collection.createdAt,
        updatedAt: current.collection.updatedAt,
      ),
      points: points,
    );
  }

  MomentCollectionDetailState _reorderPoints(
    MomentCollectionDetailState current,
    int oldIndex,
    int newIndex,
  ) {
    final points = List<MomentCollectionPointDto>.from(current.points);
    var targetIndex = newIndex;
    if (targetIndex > oldIndex) targetIndex -= 1;
    final moved = points.removeAt(oldIndex);
    points.insert(targetIndex, moved);
    return current.copyWith(points: points);
  }
}
