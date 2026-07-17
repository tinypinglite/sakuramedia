import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:sakuramedia/features/media/data/media_rapid_upload_dto.dart';
import 'package:sakuramedia/features/media/presentation/providers/media_api_provider.dart';

part 'media_rapid_upload_batch_detail_provider.g.dart';

Duration? noMediaRapidUploadBatchDetailRetry(int retryCount, Object error) =>
    null;

/// 秒传批次详情控制器（Riverpod family）：按 batchId 拉 `GET /media/rapid-uploads/{id}`
/// 得到含 items 的完整批次；`RapidUploadHistorySection` 展开批次卡时使用。
///
/// autoDispose：卡片折叠后卸载，重新展开时重新拉；页面级「展开批次 id 集合」由
/// hook `useState<Set<int>>` 管理，只要卡片仍展开，`ref.watch` 会让本 provider 保持
/// alive。
@Riverpod(retry: noMediaRapidUploadBatchDetailRetry)
Future<MediaRapidUploadBatchDto> mediaRapidUploadBatchDetail(
  Ref ref,
  int batchId,
) {
  return ref.read(mediaApiProvider).getMediaRapidUpload(batchId: batchId);
}
