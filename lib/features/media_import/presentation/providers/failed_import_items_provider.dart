import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:sakuramedia/features/media_import/data/import_failed_item_dto.dart';
import 'package:sakuramedia/features/media_import/presentation/providers/media_import_api_provider.dart';

part 'failed_import_items_provider.g.dart';

/// 某个导入任务运行记录的失败文件列表。
///
/// 弹层打开期间由承载组件按 3 秒节奏 invalidate，用于把「重试中」条目推进到
/// 已解决/待处理。
@riverpod
Future<List<ImportFailedItemDto>> failedImportItems(Ref ref, int taskRunId) {
  return ref.read(mediaImportApiProvider).getFailedItems(taskRunId: taskRunId);
}
