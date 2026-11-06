import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/widgets/base/feedback/app_toast.dart';
import 'package:sakuramedia/app/language/providers/app_localizations_provider.dart';
import 'package:sakuramedia/core/network/api_error_message.dart';
import 'package:sakuramedia/features/shared/data/batch_operation_dto.dart';
import 'package:sakuramedia/features/shared/presentation/providers/batch_operation_submission_provider.dart';
import 'package:sakuramedia/features/shared/presentation/providers/batch_operations_api_provider.dart';
import 'package:sakuramedia/l10n/app_localizations.dart';

/// 批量操作在提示文案里的名字，按当前语言渲染。
String _batchOperationLabel(
  BatchOperationType operation,
  AppLocalizations l10n,
) => switch (operation) {
  BatchOperationType.mediaDelete => l10n.sharedBatchDeleteMedia,
  BatchOperationType.clipDelete => l10n.sharedBatchDeleteClip,
  BatchOperationType.mediaPointDelete => l10n.sharedBatchDeleteMoment,
  BatchOperationType.videoDelete => l10n.sharedBatchDeleteVideo,
  BatchOperationType.clipCollectionAdd => l10n.sharedBatchAddClipsToCollection,
  BatchOperationType.clipCollectionRemove =>
    l10n.sharedBatchRemoveClipsFromCollection,
  BatchOperationType.momentCollectionAdd =>
    l10n.sharedBatchAddMomentsToCollection,
  BatchOperationType.momentCollectionRemove =>
    l10n.sharedBatchRemoveMomentsFromCollection,
  BatchOperationType.videoCollectionAdd =>
    l10n.sharedBatchAddVideosToCollection,
  BatchOperationType.videoCollectionRemove =>
    l10n.sharedBatchRemoveVideosFromCollection,
  BatchOperationType.downloadTaskDelete => l10n.sharedBatchDeleteDownloadTask,
};

/// 后端 `BatchOperationRequest.ids` 的上限，超过会被 422 拒绝。
const int maxBatchOperationItems = 1000;

/// 把整批操作提交给后端任务队列；成功与失败都只发一条 toast。
///
/// 任务进度与结果在活动中心查看；提交成功后列表不会即时变化，需用户手动刷新。
/// 返回是否提交成功，调用方据此决定是否退出多选态。
///
/// 同一批操作（类型 + 目标合集 + id 列表一致）在途期间重复调用会被拒绝，
/// 避免连点确认重复提交后端任务。
Future<bool> submitBatchOperation(
  BuildContext context,
  WidgetRef ref, {
  required BatchOperationType operation,
  required List<int> ids,
  int? targetCollectionId,
  bool deleteFiles = false,
}) async {
  final l10n = ref.read(appLocalizationsProvider);
  final label = _batchOperationLabel(operation, l10n);
  if (ids.length > maxBatchOperationItems) {
    if (context.mounted) {
      showToast(
        l10n.sharedBatchTooManyItems(label, maxBatchOperationItems, ids.length),
        tone: AppToastTone.warning,
      );
    }
    return false;
  }
  final submissionKey = batchOperationSubmissionKey(
    operation: operation,
    ids: ids,
    targetCollectionId: targetCollectionId,
  );
  final submissions = ref.read(batchOperationSubmissionProvider.notifier);
  if (!submissions.begin(submissionKey)) {
    if (context.mounted) {
      showToast(l10n.sharedBatchSubmitting(label), tone: AppToastTone.info);
    }
    return false;
  }
  try {
    await ref
        .read(batchOperationsApiProvider)
        .submit(
          operation: operation,
          ids: ids,
          targetCollectionId: targetCollectionId,
          deleteFiles: deleteFiles,
        );
  } catch (error) {
    if (context.mounted) {
      showToast(
        apiErrorMessage(
          error,
          fallback: l10n.sharedBatchSubmitFailed(label),
          l10n: l10n,
        ),
        tone: AppToastTone.error,
      );
    }
    return false;
  } finally {
    submissions.end(submissionKey);
  }
  if (context.mounted) {
    showToast(
      l10n.sharedBatchSubmitted(label, ids.length),
      tone: AppToastTone.success,
    );
  }
  return true;
}
