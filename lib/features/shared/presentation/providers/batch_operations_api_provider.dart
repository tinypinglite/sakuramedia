import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:sakuramedia/core/network/providers/api_client_provider.dart';
import 'package:sakuramedia/features/shared/data/batch_operations_api.dart';

part 'batch_operations_api_provider.g.dart';

/// 批量操作任务提交 API 的统一入口。
@Riverpod(keepAlive: true)
BatchOperationsApi batchOperationsApi(Ref ref) {
  return BatchOperationsApi(apiClient: ref.watch(apiClientProvider));
}
