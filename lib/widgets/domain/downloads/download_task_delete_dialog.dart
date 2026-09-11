import 'package:sakuramedia/widgets/base/operations/batch/batch_progress_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:sakuramedia/core/network/api_error_message.dart';
import 'package:sakuramedia/core/network/api_exception.dart';
import 'package:sakuramedia/features/downloads/data/download_request_dto.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/feedback/app_confirm_dialog.dart';
import 'package:sakuramedia/widgets/base/layout/cards/app_notice_card.dart';

Future<bool> showDownloadTaskDeleteDialog(
  BuildContext context, {
  required List<DownloadTaskDto> tasks,
  required Future<void> Function(int taskId, bool deleteFiles) onDelete,
  bool showProgress = false,
}) async {
  var deleteFiles = false;
  final remaining = tasks.toList();
  final blacklistableTaskCount = tasks
      .where(
        (task) =>
            task.importStatus == 'failed' || task.importStatus == 'skipped',
      )
      .length;
  final confirmed = await showAppConfirmDialog(
    context,
    dialogKey: const Key('download-task-delete-dialog'),
    title: '删除下载任务',
    message: '是否删除 ${tasks.length} 个下载任务？',
    danger: true,
    confirmLabel: '删除',
    failureFallback: '删除失败',
    extraContent: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (blacklistableTaskCount > 0) ...[
          AppNoticeCard(
            leadingIcon: Icons.warning_amber_rounded,
            description:
                '其中 $blacklistableTaskCount 个任务删除后，对应资源会加入资源黑名单，之后相同磁力/种子不会再次提交。',
          ),
          SizedBox(height: context.appSpacing.sm),
        ],
        _DeleteFilesCheckbox(
          onChanged: (value) => deleteFiles = value,
        ),
      ],
    ),
    onConfirm: showProgress ? null : () async {
      final confirmedDeleteFiles = deleteFiles;
      while (remaining.isNotEmpty) {
        try {
          await onDelete(remaining.first.id, confirmedDeleteFiles);
          remaining.removeAt(0);
        } catch (error) {
          final importing =
              error is ApiException &&
              error.error?.code == 'download_task_import_running';
          throw ApiException(
            message: importing
                ? '任务正在导入，无法删除'
                : apiErrorMessage(error, fallback: '删除失败'),
          );
        }
      }
    },
  );
  if (!confirmed || !showProgress || !context.mounted) return confirmed;
  final confirmedDeleteFiles = deleteFiles;
  await runBatchOperation<DownloadTaskDto>(
    context,
    title: '正在删除下载任务',
    items: tasks,
    action: (task) => onDelete(task.id, confirmedDeleteFiles),
  );
  return true;
}

class _DeleteFilesCheckbox extends HookWidget {
  const _DeleteFilesCheckbox({required this.onChanged});

  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final deleteFiles = useState(false);

    void toggle(bool value) {
      deleteFiles.value = value;
      onChanged(value);
    }

    return InkWell(
      onTap: () => toggle(!deleteFiles.value),
      borderRadius: context.appRadius.smBorder,
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: context.appSpacing.xs),
        child: Row(
          children: [
            Checkbox(
              key: const Key('download-task-delete-files-checkbox'),
              value: deleteFiles.value,
              onChanged: (value) => toggle(value ?? false),
            ),
            SizedBox(width: context.appSpacing.xs),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '同时删除下载器中的文件',
                    style: resolveAppTextStyle(
                      context,
                      size: AppTextSize.s12,
                      weight: AppTextWeight.regular,
                      tone: AppTextTone.secondary,
                    ),
                  ),
                  SizedBox(height: context.appSpacing.xs / 2),
                  Text(
                    '不影响已导入媒体库的文件',
                    style: resolveAppTextStyle(
                      context,
                      size: AppTextSize.s10,
                      weight: AppTextWeight.regular,
                      tone: AppTextTone.muted,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
