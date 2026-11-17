import 'package:sakuramedia/core/json/json_parse.dart';

/// 后端批量操作任务的操作类型；`wireValue` 与后端 `BatchOperationType` 枚举一致。
enum BatchOperationType {
  mediaDelete('media_delete'),
  clipDelete('clip_delete'),
  mediaPointDelete('media_point_delete'),
  videoDelete('video_delete'),
  clipCollectionAdd('clip_collection_add'),
  clipCollectionRemove('clip_collection_remove'),
  momentCollectionAdd('moment_collection_add'),
  momentCollectionRemove('moment_collection_remove'),
  videoCollectionAdd('video_collection_add'),
  videoCollectionRemove('video_collection_remove'),
  downloadTaskDelete('download_task_delete');

  const BatchOperationType(this.wireValue);

  final String wireValue;
}

/// `POST /batch-operations` 的受理结果：任务已进入后端队列。
///
/// 只保留 `task_run_id`：它是「提交后自动同步」这一后续扩展的唯一抓手
/// （见 `lib/features/AGENTS.md` 的批量操作条目）；`task_key` 固定为
/// `batch_operation`、`state` 固定为 `pending`，当前无消费方，不再解析。
class BatchOperationAcceptedDto {
  const BatchOperationAcceptedDto({required this.taskRunId});

  final int taskRunId;

  factory BatchOperationAcceptedDto.fromJson(Map<String, dynamic> json) {
    return BatchOperationAcceptedDto(taskRunId: asInt(json['task_run_id']));
  }
}
