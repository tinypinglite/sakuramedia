import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:sakuramedia/core/network/api_error_message.dart';
import 'package:sakuramedia/features/shared/presentation/providers/async_notifier_dispose_guard.dart';
import 'package:sakuramedia/features/shared/presentation/providers/optimistic_patch_mixin.dart';
import 'package:sakuramedia/features/shared/presentation/providers/paged_async_notifier.dart';
import 'package:sakuramedia/features/videos/data/dto/video_collection_dto.dart';
import 'package:sakuramedia/features/videos/presentation/controllers/listing/video_filter_state.dart';
import 'package:sakuramedia/features/videos/presentation/providers/video_collection_detail_state.dart';
import 'package:sakuramedia/features/videos/presentation/providers/video_collection_sort.dart';
import 'package:sakuramedia/features/videos/presentation/providers/videos_api_provider.dart';

part 'video_collection_detail_provider.g.dart';

/// 视频合集详情：加载合集元信息 + 全量有序成员，支持排序、乐观重排与移除。
///
/// **本仓库第二个 [OptimisticPatchMixin] 采用者**（首个：clip_collection_detail）：
/// reorder / removeItem / deleteVideo 三处都用 [withOptimisticPatch]，共用
/// [_mutationKey] 让「同时只允许一个 mutation」（等价原 controller `_isMutating`
/// bool）。reorder **返回 `Future<void>`**（原 controller 语义）——失败静默回滚，
/// UI 无 toast；removeItem / deleteVideo **返回 `Future<String?>`** 兼容原 UI
/// 调用点的 `if (error != null) showToast(error)` 模式。
///
/// [applySort] 走独立的「保留旧列表 → 拉新排序 → 覆盖」路径，不占 [_mutationKey]，
/// 与批 2 的筛选切换视觉策略一致（现有 controller 也是这么做的：`applySort` 期间
/// items 保留、失败仍保留原列表并写 errorMessage）。
///
/// family(collectionId) + autoDispose：每合集独立实例，离开页面即释放。
@Riverpod(retry: kNoAsyncNotifierRetry)
class VideoCollectionDetail extends _$VideoCollectionDetail
    with
        AsyncNotifierDisposeGuardMixin<VideoCollectionDetailState>,
        OptimisticPatchMixin<VideoCollectionDetailState> {
  static const Object _mutationKey = #videoCollectionDetailMutation;
  late final DebouncedLatestRequest _sortRequests = DebouncedLatestRequest();

  @override
  Future<VideoCollectionDetailState> build(int collectionId) async {
    attachDisposeGuard();
    ref.onDispose(_sortRequests.dispose);
    final api = ref.read(videoCollectionsApiProvider);
    final collection = await api.getCollection(collectionId: collectionId);
    final items = await api.getAllCollectionItems(
      collectionId: collectionId,
      sort: VideoCollectionSort.manual.apiValue,
      // 带上播放地址：成员既供详情列表展示，也可经「交接信箱」直接交给连播页
      // 组装播放列表，省去连播页二次全量拉取。
      includePlayUrl: true,
    );
    return VideoCollectionDetailState(
      collection: collection,
      items: items,
      sort: VideoCollectionSort.manual,
    );
  }

  Future<void> refresh() async {
    final current = state.value;
    if (current == null) {
      ref.invalidateSelf();
      return;
    }
    _sortRequests.cancel();
    try {
      final api = ref.read(videoCollectionsApiProvider);
      final collection = await api.getCollection(collectionId: collectionId);
      final items = await api.getAllCollectionItems(
        collectionId: collectionId,
        sort: current.sort.apiValue,
        includePlayUrl: true,
      );
      if (isDisposed) return;
      state = AsyncData(
        current.copyWith(
          collection: collection,
          items: items,
          filterUpdate: const FilterUpdateState.idle(),
        ),
      );
    } catch (error, stack) {
      if (isDisposed) return;
      state = AsyncError(error, stack);
    }
  }

  /// 切换排序：保留旧 items 直到新数据回来（对齐原 controller `applySort`
  /// 视觉——不切 AsyncLoading，与「筛选切换保留列表」策略一致）。
  Future<void> applySort({
    required VideoSortField? field,
    SortDirection? direction,
  }) {
    final current = state.value;
    if (current == null) return Future<void>.value();
    final nextSort = current.sort.copyWith(field: field, direction: direction);
    if (nextSort == current.sort) return Future<void>.value();
    // 先写 sort（工具条与拖拽开关即时切换），保留旧 items 到新数据回来。
    state = AsyncData(
      current.copyWith(
        sort: nextSort,
        filterUpdate: const FilterUpdateState.loading(),
      ),
    );
    return _sortRequests.schedule(
      (requestId) => _loadSort(requestId, nextSort),
    );
  }

  Future<void> retrySort() {
    final current = state.value;
    if (current == null) return Future<void>.value();
    state = AsyncData(
      current.copyWith(filterUpdate: const FilterUpdateState.loading()),
    );
    return _sortRequests.runNow(
      (requestId) => _loadSort(requestId, current.sort),
    );
  }

  Future<void> _loadSort(int requestId, VideoCollectionSort sort) async {
    final current = state.value;
    if (current == null) return;
    try {
      final items = await ref
          .read(videoCollectionsApiProvider)
          .getAllCollectionItems(
            collectionId: collectionId,
            sort: sort.apiValue,
            includePlayUrl: true,
          );
      if (isDisposed || !_sortRequests.isCurrent(requestId)) return;
      final now = state.value ?? current;
      state = AsyncData(
        now.copyWith(
          items: items,
          filterUpdate: const FilterUpdateState.idle(),
        ),
      );
    } catch (error) {
      if (isDisposed || !_sortRequests.isCurrent(requestId)) return;
      final now = state.value ?? current;
      state = AsyncData(
        now.copyWith(
          filterUpdate: FilterUpdateState.failed(
            apiErrorMessage(error, fallback: '筛选结果更新失败，请重试'),
          ),
        ),
      );
    }
  }

  /// 乐观重排：本地立即移动 → API → 失败回滚。返回 `Future<void>`（原 controller
  /// 语义，UI 侧不 toast reorder 错误）。
  ///
  /// 视频合集 reorder **必须提交全部成员**（后端 422）；apply 生成完整列表，
  /// action 传全量 orderedItemIds。
  Future<void> reorder(int oldIndex, int newIndex) async {
    final current = state.value;
    if (current == null) return;
    if (oldIndex < 0 || oldIndex >= current.items.length) return;
    var target = newIndex;
    if (target > oldIndex) target -= 1;
    if (target < 0) target = 0;
    if (target >= current.items.length) target = current.items.length - 1;
    if (target == oldIndex) return;

    try {
      await withOptimisticPatch<void>(
        key: _mutationKey,
        apply: (s) {
          final next = List<VideoCollectionItemDto>.of(s.items);
          final moved = next.removeAt(oldIndex);
          next.insert(target, moved);
          return s.copyWith(items: next);
        },
        action: () async {
          final applied =
              state.value?.items ?? const <VideoCollectionItemDto>[];
          await ref
              .read(videoCollectionsApiProvider)
              .reorderCollectionItems(
                collectionId: collectionId,
                orderedItemIds: applied
                    .map((item) => item.itemId)
                    .toList(growable: false),
              );
        },
      );
    } catch (_) {
      // 与原 controller 语义一致：reorder 失败静默回滚（mixin 已回滚 state），
      // UI 侧不弹 toast。
    }
  }

  /// 从合集移除成员（乐观更新）；失败回滚并返回错误消息。
  Future<String?> removeItem(int itemId) async {
    try {
      return await withOptimisticPatch<String?>(
        key: _mutationKey,
        apply: (s) => s.copyWith(
          items: s.items
              .where((item) => item.itemId != itemId)
              .toList(growable: false),
        ),
        action: () async {
          await ref
              .read(videoCollectionsApiProvider)
              .removeCollectionItem(collectionId: collectionId, itemId: itemId);
          return null;
        },
      );
    } catch (error) {
      return apiErrorMessage(error, fallback: '移除失败，请重试');
    }
  }

  /// 彻底删除视频本体（连同文件，不可恢复）；乐观更新，失败回滚并返回错误消息。
  /// 与 [removeItem] 区别：调用 `videosApi.deleteVideo` 删除视频本身而非仅解除
  /// 合集归属，调用方成功后应广播 `reportDeleted`（而非成员变化）。
  Future<String?> deleteVideo(int itemId, int videoId) async {
    try {
      return await withOptimisticPatch<String?>(
        key: _mutationKey,
        apply: (s) => s.copyWith(
          items: s.items
              .where((item) => item.itemId != itemId)
              .toList(growable: false),
        ),
        action: () async {
          await ref.read(videosApiProvider).deleteVideo(videoId);
          return null;
        },
      );
    } catch (error) {
      return apiErrorMessage(error, fallback: '删除失败，请重试');
    }
  }
}
