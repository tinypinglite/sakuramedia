import 'package:flutter/material.dart';
import 'package:sakuramedia/features/media_import/data/media_import_source.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/actions/app_button.dart';
import 'package:sakuramedia/widgets/base/overlays/app_adaptive_modal.dart';
import 'package:sakuramedia/widgets/domain/media_import/media_import_source_picker.dart';

/// 选择服务器本地目录并创建 JAV 字幕导入任务。
Future<String?> showSubtitleImportDialog(BuildContext context) {
  return showAppAdaptiveModal<String>(
    context: context,
    modalKey: const Key('subtitle-import-directory-picker-modal'),
    builder: (_) => const _SubtitleImportDialog(),
  );
}

class _SubtitleImportDialog extends StatefulWidget {
  const _SubtitleImportDialog();

  @override
  State<_SubtitleImportDialog> createState() => _SubtitleImportDialogState();
}

class _SubtitleImportDialogState extends State<_SubtitleImportDialog> {
  String? _sourcePath;

  bool get _canSubmit => _sourcePath?.trim().isNotEmpty ?? false;

  void _handleSourceChanged(MediaImportSource? source) {
    final nextPath = switch (source) {
      LocalMediaImportSource(:final path) => path,
      _ => null,
    };
    if (nextPath == _sourcePath) {
      return;
    }
    setState(() => _sourcePath = nextPath);
  }

  @override
  Widget build(BuildContext context) {
    final spacing = context.appSpacing;
    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '新建 JAV 字幕导入',
            style: resolveAppTextStyle(
              context,
              size: AppTextSize.s18,
              weight: AppTextWeight.semibold,
              tone: AppTextTone.primary,
            ),
          ),
          SizedBox(height: spacing.sm),
          Text(
            '仅支持 .srt 文件。系统会递归扫描所选目录，并按文件名中的番号匹配已入库影片；源文件将保留。',
            style: resolveAppTextStyle(
              context,
              size: AppTextSize.s12,
              tone: AppTextTone.muted,
            ),
          ),
          SizedBox(height: spacing.md),
          MediaImportSourcePicker(
            selectedLibrary: null,
            transferMode: TransferMode.auto,
            localOnly: true,
            onSourceChanged: _handleSourceChanged,
            onTransferModeChanged: (_) {},
          ),
          SizedBox(height: spacing.xl),
          Row(
            children: [
              Expanded(
                child: AppButton(
                  key: const Key('subtitle-import-picker-cancel-button'),
                  label: '取消',
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ),
              SizedBox(width: spacing.md),
              Expanded(
                child: AppButton(
                  key: const Key('subtitle-import-picker-submit-button'),
                  label: '开始导入',
                  variant: AppButtonVariant.primary,
                  onPressed: _canSubmit
                      ? () => Navigator.of(context).pop(_sourcePath!.trim())
                      : null,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
