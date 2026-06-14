import 'package:flutter/material.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/actions/app_button.dart';
import 'package:sakuramedia/widgets/app_bottom_drawer.dart';
import 'package:sakuramedia/widgets/app_desktop_dialog.dart';
import 'package:sakuramedia/widgets/forms/app_text_field.dart';

/// 切片重命名的呈现形态：桌面弹窗 / 移动端底部抽屉。
enum RenameClipDialogPresentation { dialog, bottomDrawer }

/// 弹出切片重命名对话框，返回新标题；取消返回 `null`。
Future<String?> showRenameClipDialog(
  BuildContext context, {
  required String initialTitle,
  RenameClipDialogPresentation presentation =
      RenameClipDialogPresentation.dialog,
}) {
  switch (presentation) {
    case RenameClipDialogPresentation.dialog:
      return showDialog<String>(
        context: context,
        builder:
            (dialogContext) => RenameClipDialog(initialTitle: initialTitle),
      );
    case RenameClipDialogPresentation.bottomDrawer:
      return showAppBottomDrawer<String>(
        context: context,
        drawerKey: const Key('rename-clip-bottom-sheet'),
        maxHeightFactor: 0.5,
        builder:
            (sheetContext) => RenameClipDialog(
              initialTitle: initialTitle,
              presentation: RenameClipDialogPresentation.bottomDrawer,
            ),
      );
  }
}

class RenameClipDialog extends StatefulWidget {
  const RenameClipDialog({
    super.key,
    required this.initialTitle,
    this.presentation = RenameClipDialogPresentation.dialog,
  });

  final String initialTitle;
  final RenameClipDialogPresentation presentation;

  @override
  State<RenameClipDialog> createState() => _RenameClipDialogState();
}

class _RenameClipDialogState extends State<RenameClipDialog> {
  late final TextEditingController _titleController;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.initialTitle);
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  void _submit() {
    Navigator.of(context).pop(_titleController.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    if (widget.presentation == RenameClipDialogPresentation.dialog) {
      return AppDesktopDialog(
        width: context.appComponentTokens.playlistDialogWidth,
        child: _buildContent(context),
      );
    }
    return SingleChildScrollView(child: _buildContent(context));
  }

  Widget _buildContent(BuildContext context) {
    final spacing = context.appSpacing;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '重命名切片',
          style: resolveAppTextStyle(
            context,
            size: AppTextSize.s16,
            weight: AppTextWeight.semibold,
            tone: AppTextTone.primary,
          ),
        ),
        SizedBox(height: spacing.md),
        AppTextField(
          fieldKey: const Key('rename-clip-title-field'),
          controller: _titleController,
          hintText: '切片标题（可留空）',
          textInputAction: TextInputAction.done,
          onFieldSubmitted: (_) => _submit(),
        ),
        SizedBox(height: spacing.md),
        Row(
          children: [
            Expanded(
              child: AppButton(
                label: '取消',
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
            SizedBox(width: spacing.md),
            Expanded(
              child: AppButton(
                key: const Key('rename-clip-submit-button'),
                label: '保存',
                variant: AppButtonVariant.primary,
                onPressed: _submit,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
