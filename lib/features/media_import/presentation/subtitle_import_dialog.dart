import 'package:flutter/material.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/actions/app_button.dart';
import 'package:sakuramedia/widgets/base/forms/app_text_field.dart';
import 'package:sakuramedia/widgets/base/overlays/app_adaptive_modal.dart';

/// The subtitle endpoint currently accepts a server-side source path directly.
/// It is intentionally kept separate from provider source browsing because that
/// endpoint has not adopted opaque provider references yet.
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
  late final TextEditingController _sourcePathController;

  bool get _canSubmit => _sourcePathController.text.trim().isNotEmpty;

  @override
  void initState() {
    super.initState();
    _sourcePathController = TextEditingController()..addListener(_onChanged);
  }

  @override
  void dispose() {
    _sourcePathController
      ..removeListener(_onChanged)
      ..dispose();
    super.dispose();
  }

  void _onChanged() => setState(() {});

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
            '输入后端可访问的字幕目录或 .srt 文件路径。源文件会保留。',
            style: resolveAppTextStyle(
              context,
              size: AppTextSize.s12,
              tone: AppTextTone.muted,
            ),
          ),
          SizedBox(height: spacing.md),
          AppTextField(
            fieldKey: const Key('subtitle-import-source-path-field'),
            controller: _sourcePathController,
            label: '字幕目录或文件路径',
            hintText: '/media/subtitles',
            textInputAction: TextInputAction.done,
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
                      ? () => Navigator.of(
                          context,
                        ).pop(_sourcePathController.text.trim())
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
