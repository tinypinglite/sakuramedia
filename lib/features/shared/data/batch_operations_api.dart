import 'package:sakuramedia/core/network/api_client.dart';
import 'package:sakuramedia/features/shared/data/batch_operation_dto.dart';

/// 批量操作任务提交入口：一次 POST 把整批操作交给后端任务队列执行。
class BatchOperationsApi {
  const BatchOperationsApi({required ApiClient apiClient})
    : _apiClient = apiClient;

  final ApiClient _apiClient;

  Future<BatchOperationAcceptedDto> submit({
    required BatchOperationType operation,
    required List<int> ids,
    int? targetCollectionId,
    bool deleteFiles = false,
  }) async {
    final response = await _apiClient.post(
      '/batch-operations',
      data: <String, dynamic>{
        'operation': operation.wireValue,
        'ids': ids,
        if (targetCollectionId != null) 'target_collection_id': targetCollectionId,
        'delete_files': deleteFiles,
      },
    );
    return BatchOperationAcceptedDto.fromJson(response);
  }
}
