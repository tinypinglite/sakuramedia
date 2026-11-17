import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:sakuramedia/features/shared/presentation/providers/async_notifier_dispose_guard.dart';
import 'package:sakuramedia/features/videos/data/dto/video_collection_dto.dart';
import 'package:sakuramedia/features/videos/presentation/providers/videos_api_provider.dart';

part 'video_collections_overview_provider.g.dart';

/// 视频合集列表（一次性拉全，后端 `/video-collections` 不分页）。
///
/// 迁移前对应：`VideoCollectionsOverviewController`（仅 load / refresh 两方法）。
/// 与切片合集不同，本 provider **无 insert / replace / remove 补丁方法**——
/// 现有 UI 在新建 / 编辑 / 删除后都是 `await refresh()` 走整拉重刷（合集列表小，
/// 且服务端计算封面 / 计数，本地补丁不划算）。
///
/// autoDispose：离开页面即释放。
@Riverpod(retry: kNoAsyncNotifierRetry)
class VideoCollectionsOverview extends _$VideoCollectionsOverview
    with AsyncNotifierDisposeGuardMixin<List<VideoCollectionDto>> {
  @override
  Future<List<VideoCollectionDto>> build() async {
    attachDisposeGuard();
    return ref.read(videoCollectionsApiProvider).getCollections();
  }

  /// 保留态刷新：不切 loading；失败置 [AsyncError] 由 UI 兜底展示。
  Future<void> refresh() async {
    try {
      final next =
          await ref.read(videoCollectionsApiProvider).getCollections();
      if (isDisposed) return;
      state = AsyncData(next);
    } catch (error, stack) {
      if (isDisposed) return;
      state = AsyncError(error, stack);
    }
  }
}
