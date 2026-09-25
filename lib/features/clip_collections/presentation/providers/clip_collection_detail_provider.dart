import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:sakuramedia/core/network/api_error_message.dart';
import 'package:sakuramedia/features/clip_collections/data/dto/clip_collection_dto.dart';
import 'package:sakuramedia/features/clip_collections/presentation/providers/clip_collection_detail_state.dart';
import 'package:sakuramedia/features/clip_collections/presentation/providers/clip_collections_api_provider.dart';
import 'package:sakuramedia/features/clips/presentation/providers/clips_api_provider.dart';
import 'package:sakuramedia/features/shared/presentation/providers/async_notifier_dispose_guard.dart';
import 'package:sakuramedia/features/shared/presentation/providers/optimistic_patch_mixin.dart';

part 'clip_collection_detail_provider.g.dart';

/// 切片合集详情：加载合集元信息 + 全量切片，支持移除、删除本体。
///
/// 合集切片量通常不大，这里一次性把所有分页拉全。
///
/// removeClip / deleteClip 两处都用 [withOptimisticPatch]（本地立即变
/// → await API → 失败整体回滚）。两处共用 [_mutationKey]，保证同一合集同时只
/// 执行一个 mutation。
///
/// removeClip 返回 `Future<String?>`（成功 null / 失败错误文案）；
/// deleteClip 则将异常交给确认弹层处理，以便请求中保持确认按钮的 loading 状态。
///
/// family(collectionId) + autoDispose：每合集独立实例，离开页面即释放。
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
  /// 失败时回滚并 rethrow。与 [removeClip]（仅解除本合集关联）语义不同。
  Future<void> deleteClip(int clipId) async {
    await withOptimisticPatch<void>(
      key: _mutationKey,
      apply: (current) => _dropClip(current, clipId),
      action: () => ref.read(clipsApiProvider).deleteClip(clipId: clipId),
    );
  }

  /// 编辑合集名称 / 描述后就地更新头部元信息（不重拉切片列表）。
  ///
  /// 保留 `clipCount = state.clips.length`：编辑响应中的计数可能尚未更新（服务端仅
  /// 在成员变化时更新），本地列表更可靠。
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
