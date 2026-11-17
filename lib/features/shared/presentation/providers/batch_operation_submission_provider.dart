import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sakuramedia/features/shared/data/batch_operation_dto.dart';

/// 在途批量操作的登记表（键 = 操作类型 + 目标合集 + 整批 id）。
///
/// 两个用途：
/// 1. [batch_operation_submit.dart] 的提交入口用它拦截同一批操作的重复提交——
///    确认弹窗在请求返回前就关闭了，连点两次会向后端提交两个任务；
/// 2. 各页批量按钮 watch 它，在提交期间禁用按钮，给用户即时反馈。
///
/// 手动 provider（非 codegen）：跨页共享且需要在整个提交周期内存活，
/// 不随任何页面销毁而清空。
class BatchOperationSubmission extends Notifier<Set<String>> {
  @override
  Set<String> build() => const <String>{};

  /// 登记一批操作开始提交；同一批已在提交中时返回 false。
  bool begin(String key) {
    if (state.contains(key)) {
      return false;
    }
    state = {...state, key};
    return true;
  }

  void end(String key) {
    if (!state.contains(key)) {
      return;
    }
    state = {...state}..remove(key);
  }
}

final batchOperationSubmissionProvider =
    NotifierProvider<BatchOperationSubmission, Set<String>>(
      BatchOperationSubmission.new,
    );

/// 提交去重键：操作类型 + 目标合集 + 整批 id 完全一致才算同一批。
String batchOperationSubmissionKey({
  required BatchOperationType operation,
  required List<int> ids,
  int? targetCollectionId,
}) {
  return '${operation.wireValue}|${targetCollectionId ?? ''}|${ids.join(',')}';
}

/// [keys] 中是否有任一给定操作类型的在途提交（纯函数，供 select 用）。
bool isBatchOperationSubmitting(
  Set<String> keys,
  Iterable<BatchOperationType> operations,
) {
  for (final operation in operations) {
    final prefix = '${operation.wireValue}|';
    if (keys.any((key) => key.startsWith(prefix))) {
      return true;
    }
  }
  return false;
}

/// 页面侧便捷入口：watch 给定操作类型是否有在途提交，用于禁用批量按钮。
bool watchBatchOperationSubmitting(
  WidgetRef ref,
  Iterable<BatchOperationType> operations,
) {
  return ref.watch(
    batchOperationSubmissionProvider.select(
      (keys) => isBatchOperationSubmitting(keys, operations),
    ),
  );
}
