import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:sakuramedia/core/network/api_error_message.dart';
import 'package:sakuramedia/features/clip_collections/data/dto/clip_collection_dto.dart';
import 'package:sakuramedia/features/clip_collections/presentation/providers/clip_collection_detail_state.dart';
import 'package:sakuramedia/features/clip_collections/presentation/providers/clip_collections_api_provider.dart';
import 'package:sakuramedia/features/clips/data/dto/media_clip_dto.dart';
import 'package:sakuramedia/features/clips/presentation/providers/clips_api_provider.dart';
import 'package:sakuramedia/features/shared/presentation/providers/async_notifier_dispose_guard.dart';
import 'package:sakuramedia/features/shared/presentation/providers/optimistic_patch_mixin.dart';

part 'clip_collection_detail_provider.g.dart';

/// 切片合集详情：加载合集元信息 + 全量有序切片，支持拖序、移除、删除本体。
///
/// 合集切片量通常不大，这里一次性把所有分页拉全，便于本地重排后用
/// `setCollectionClips` 提交完整有序列表（后端按列表重新编号 position）。
///
/// **本仓库首个 [OptimisticPatchMixin] 业务采用者**：reorder / removeClip /
/// deleteClip 三处都用 [withOptimisticPatch]（本地立即变 → await API → 失败
/// 整体回滚）。三处共用 [_mutationKey]：保持原 controller 「同时只允许一个
/// mutation」的语义（先前 `_isMutating` bool 的等价）。
///
/// 三个 mutation 方法**保留返回 `Future<String?>`（成功 null / 失败错误文案）
/// 的 UI 兼容语义**——mixin 内核是 rethrow，本 provider 在外包 try/catch
/// 转文案，让两个 detail page 的 UI 调用点不动。
///
/// family(collectionId) + autoDispose：每合集独立实例，离开页面即释放；对齐
/// `mediaRapidUploadBatchDetail` 唯一 autoDispose family 先例。
@Riverpod(retry: kNoAsyncNotifierRetry)
class ClipCollectionDetail extends _$ClipCollectionDetail
    with
        AsyncNotifierDisposeGuardMixin<ClipCollectionDetailState>,
        OptimisticPatchMixin<ClipCollectionDetailState> {
  static const Object _mutationKey = #clipCollectionDetailMutation;
  static const int _pageSize = 50;

  @override
  Future<ClipCollectionDetailState> build(int collectionId) async {
    attachDisposeGuard();
    final api = ref.read(clipCollectionsApiProvider);
    final detail = await api.getCollectionDetail(collectionId: collectionId);
    final clips = await api.getAllCollectionClips(
      collectionId: collectionId,
      pageSize: _pageSize,
    );
    return ClipCollectionDetailState(collection: detail, clips: clips);
  }

  Future<void> refresh() async {
    try {
      final api = ref.read(clipCollectionsApiProvider);
      final detail = await api.getCollectionDetail(collectionId: collectionId);
      final clips = await api.getAllCollectionClips(
        collectionId: collectionId,
        pageSize: _pageSize,
      );
      if (isDisposed) return;
      state = AsyncData(
        ClipCollectionDetailState(collection: detail, clips: clips),
      );
    } catch (error, stack) {
      if (isDisposed) return;
      state = AsyncError(error, stack);
    }
  }

  /// 本地重排并提交完整有序列表；失败时回滚并返回错误消息。
  Future<String?> reorder(int oldIndex, int newIndex) async {
    try {
      return await withOptimisticPatch<String?>(
        key: _mutationKey,
        apply: (current) {
          final updated = List<MediaClipDto>.from(current.clips);
          var targetIndex = newIndex;
          if (targetIndex > oldIndex) {
            targetIndex -= 1;
          }
          final moved = updated.removeAt(oldIndex);
          updated.insert(targetIndex, moved);
          return current.copyWith(clips: updated);
        },
        action: () async {
          final applied = state.value?.clips ?? const <MediaClipDto>[];
          await ref.read(clipCollectionsApiProvider).setCollectionClips(
                collectionId: collectionId,
                clipIds:
                    applied.map((clip) => clip.clipId).toList(growable: false),
              );
          return null;
        },
      );
    } catch (error) {
      return apiErrorMessage(error, fallback: '排序失败，请重试');
    }
  }

  /// 从合集移除切片（乐观更新）；失败时回滚并返回错误消息。
  Future<String?> removeClip(int clipId) async {
    try {
      return await withOptimisticPatch<String?>(
        key: _mutationKey,
        apply: (current) => _dropClip(current, clipId),
        action: () async {
          await ref
              .read(clipCollectionsApiProvider)
              .removeClipFromCollection(
                collectionId: collectionId,
                clipId: clipId,
              );
          return null;
        },
      );
    } catch (error) {
      return apiErrorMessage(error, fallback: '移除失败，请重试');
    }
  }

  /// 删除切片本体（硬删，连同文件，并由后端从所有合集级联移除）；乐观更新，
  /// 失败时回滚并返回错误消息。与 [removeClip]（仅解除本合集关联）语义不同。
  Future<String?> deleteClip(int clipId) async {
    try {
      return await withOptimisticPatch<String?>(
        key: _mutationKey,
        apply: (current) => _dropClip(current, clipId),
        action: () async {
          await ref.read(clipsApiProvider).deleteClip(clipId: clipId);
          return null;
        },
      );
    } catch (error) {
      return apiErrorMessage(error, fallback: '删除失败，请重试');
    }
  }

  /// 编辑合集名称 / 描述后就地更新头部元信息（不重拉切片列表）。
  ///
  /// 保留 `clipCount = state.clips.length`：编辑响应可能是旧计数（服务端仅在成员
  /// 变化时更新），本地列表更可靠。
  void applyCollectionMeta(ClipCollectionDto next) {
    final current = state.value;
    if (current == null) return;
    state = AsyncData(
      current.copyWith(
        collection: next.copyWith(clipCount: current.clips.length),
      ),
    );
  }

  ClipCollectionDetailState _dropClip(
    ClipCollectionDetailState current,
    int clipId,
  ) {
    final next = current.clips
        .where((clip) => clip.clipId != clipId)
        .toList(growable: false);
    if (next.length == current.clips.length) {
      return current;
    }
    return current.copyWith(
      clips: next,
      collection: current.collection.copyWith(clipCount: next.length),
    );
  }
}
