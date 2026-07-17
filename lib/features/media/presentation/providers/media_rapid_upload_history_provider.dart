import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:sakuramedia/core/network/paginated_response_dto.dart';
import 'package:sakuramedia/features/media/data/media_rapid_upload_dto.dart';
import 'package:sakuramedia/features/media/presentation/providers/media_api_provider.dart';
import 'package:sakuramedia/features/shared/presentation/providers/paged_async_notifier.dart';

part 'media_rapid_upload_history_provider.g.dart';

Duration? noMediaRapidUploadHistoryRetry(int retryCount, Object error) => null;

/// 秒传批次历史控制器（Riverpod）：只读分页 + 单批次覆盖更新。
///
/// 触发/重试成功后，页面调 [refreshBatch] 拉最新详情 upsert 进列表，
/// 避免整页 reload；State 就是 [PagedListState]（无附加字段）。
///
/// 迁移前对应：`MediaRapidUploadHistoryController extends PagedLoadController<...>`。
@Riverpod(keepAlive: true, retry: noMediaRapidUploadHistoryRetry)
class MediaRapidUploadHistory extends _$MediaRapidUploadHistory
    with
        PagedAsyncNotifierMixin<
          PagedListState<MediaRapidUploadBatchListItemDto>,
          MediaRapidUploadBatchListItemDto
        > {
  @override
  int get pageSize => 20;

  @override
  String get initialLoadErrorText => '秒传批次加载失败，请稍后重试';

  @override
  String get loadMoreErrorText => '加载更多秒传批次失败，请点击重试';

  @override
  PagedListState<MediaRapidUploadBatchListItemDto> pagedOf(
    PagedListState<MediaRapidUploadBatchListItemDto> state,
  ) => state;

  @override
  PagedListState<MediaRapidUploadBatchListItemDto> applyPaged(
    PagedListState<MediaRapidUploadBatchListItemDto> state,
    PagedListState<MediaRapidUploadBatchListItemDto> paged,
  ) => paged;

  @override
  Future<PaginatedResponseDto<MediaRapidUploadBatchListItemDto>> fetchPage(
    int page,
    int pageSize,
  ) => ref
      .read(mediaApiProvider)
      .getMediaRapidUploads(page: page, pageSize: pageSize);

  @override
  Future<PagedListState<MediaRapidUploadBatchListItemDto>> build() async {
    attachDisposeGuard();
    return loadInitialPage();
  }

  /// 把服务端最新批次合并进列表：已存在 → 覆盖；不存在 → 插到最前。
  void upsertBatch(MediaRapidUploadBatchListItemDto batch) {
    final current = state.value;
    if (current == null) return;
    final index = current.items.indexWhere((item) => item.id == batch.id);
    final nextItems = List<MediaRapidUploadBatchListItemDto>.of(current.items);
    var totalDelta = 0;
    if (index >= 0) {
      nextItems[index] = batch;
    } else {
      nextItems.insert(0, batch);
      totalDelta = 1;
    }
    final nextTotal = current.total + totalDelta;
    state = AsyncData(
      current.copyWith(
        items: List<MediaRapidUploadBatchListItemDto>.unmodifiable(nextItems),
        total: nextTotal,
        hasMore: nextItems.length < nextTotal,
      ),
    );
  }

  /// 拉某个批次的最新详情，成功后 upsert。返回原详情供调用方按需消费。
  Future<MediaRapidUploadBatchDto> refreshBatch(int batchId) async {
    final detail = await ref
        .read(mediaApiProvider)
        .getMediaRapidUpload(batchId: batchId);
    if (!isDisposed) {
      upsertBatch(detail);
    }
    return detail;
  }
}
