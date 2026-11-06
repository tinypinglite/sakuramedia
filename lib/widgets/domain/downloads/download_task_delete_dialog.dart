import 'package:material_ui/material_ui.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:sakuramedia/features/downloads/data/download_request_dto.dart';
import 'package:sakuramedia/l10n/app_localizations.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/feedback/app_confirm_dialog.dart';
import 'package:sakuramedia/widgets/base/interaction/app_interactive_surface.dart';
import 'package:sakuramedia/widgets/base/layout/cards/app_notice_card.dart';

/// 下载任务删除确认弹窗：返回用户勾选的「同时删除下载器文件」选项；
/// 取消返回 `null`。
///
/// - 传 [onConfirm] 时由弹窗执行删除：确认按钮显示 loading、请求期间禁止
///   取消/关闭，成功后才关闭；失败 toast 并保持打开，可重试或取消。
/// - 不传时仅收集选项，实际删除由调用方提交批量操作任务执行。
Future<bool?> showDownloadTaskDeleteDialog(
  BuildContext context, {
  required List<DownloadTaskDto> tasks,
  Future<void> Function(bool deleteFiles)? onConfirm,
}) async {
  var deleteFiles = false;
  final l10n = AppLocalizations.of(context);
  final blacklistableTaskCount = tasks
      .where((task) => task.blacklistable)
      .length;
  final confirmed = await showAppConfirmDialog(
    context,
    dialogKey: const Key('download-task-delete-dialog'),
    title: l10n.widgetDownloadDeleteTitle,
    message: l10n.widgetDownloadDeleteMessage(tasks.length),
    danger: true,
    confirmLabel: l10n.commonDelete,
    failureFallback: l10n.widgetDownloadDeleteFailure,
    onConfirm: onConfirm == null ? null : () => onConfirm(deleteFiles),
    extraContent: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (blacklistableTaskCount > 0) ...[
          AppNoticeCard(
            leadingIcon: Icons.warning_amber_rounded,
            description: l10n.widgetDownloadDeleteBlacklistNotice(
              blacklistableTaskCount,
            ),
          ),
          SizedBox(height: context.appSpacing.sm),
        ],
        _DeleteFilesCheckbox(onChanged: (value) => deleteFiles = value),
      ],
    ),
  );
  if (!confirmed) return null;
  return deleteFiles;
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

    return AppInteractiveSurface(
      onTap: () => toggle(!deleteFiles.value),
      focusRingRadius: context.appRadius.smBorder,
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
                    AppLocalizations.of(context).widgetDownloadDeleteFilesLabel,
                    style: resolveAppTextStyle(
                      context,
                      size: AppTextSize.s12,
                      weight: AppTextWeight.regular,
                      tone: AppTextTone.secondary,
                    ),
                  ),
                  SizedBox(height: context.appSpacing.xs / 2),
                  Text(
                    AppLocalizations.of(context).widgetDownloadDeleteFilesHint,
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
