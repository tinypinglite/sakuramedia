import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:sakuramedia/features/clip_collections/data/dto/clip_collection_dto.dart';
import 'package:sakuramedia/features/clip_collections/presentation/providers/clip_collections_api_provider.dart';
import 'package:sakuramedia/features/shared/presentation/providers/async_notifier_dispose_guard.dart';

part 'clip_collections_overview_provider.g.dart';

/// 切片合集列表（一次性拉全，后端 `/clip-collections` 不分页）。
///
/// 迁移前对应：`ClipCollectionsOverviewController`。补丁方法 [insertCollection]
/// / [replaceCollection] / [removeCollection] 保留：外部动作成功后调用即可就地
/// 打补丁，不整页 invalidate 重拉。
///
/// autoDispose：离开页面即释放。
@Riverpod(retry: kNoAsyncNotifierRetry)
class ClipCollectionsOverview extends _$ClipCollectionsOverview
    with AsyncNotifierDisposeGuardMixin<List<ClipCollectionDto>> {
  @override
  Future<List<ClipCollectionDto>> build() async {
    attachDisposeGuard();
    return ref.read(clipCollectionsApiProvider).getCollections();
  }

  /// 保留态刷新：不切 loading；失败返回中文错误消息由页面 toast。
  Future<void> refresh() async {
    try {
      final next =
          await ref.read(clipCollectionsApiProvider).getCollections();
      if (isDisposed) return;
      state = AsyncData(next);
    } catch (error, stack) {
      if (isDisposed) return;
      state = AsyncError(error, stack);
    }
  }

  /// 新建合集后置顶插入（后端列表按更新时间倒序，新建即最新）。
  void insertCollection(ClipCollectionDto collection) {
    final current = state.value;
    if (current == null) return;
    state = AsyncData(<ClipCollectionDto>[collection, ...current]);
  }

  void replaceCollection(ClipCollectionDto collection) {
    final current = state.value;
    if (current == null) return;
    final index = current.indexWhere((item) => item.id == collection.id);
    if (index < 0) return;
    final next = List<ClipCollectionDto>.from(current);
    next[index] = collection;
    state = AsyncData(next);
  }

  void removeCollection(int collectionId) {
    final current = state.value;
    if (current == null) return;
    final next = current
        .where((item) => item.id != collectionId)
        .toList(growable: false);
    if (next.length == current.length) return;
    state = AsyncData(next);
  }
}
