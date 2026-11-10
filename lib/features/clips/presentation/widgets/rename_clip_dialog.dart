import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/l10n/app_localizations.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/forms/app_text_field.dart';
import 'package:sakuramedia/widgets/base/overlays/app_adaptive_modal.dart';
import 'package:sakuramedia/widgets/base/overlays/app_modal_action_row.dart';

/// 弹出切片重命名对话框，返回新标题；取消返回 `null`。
Future<String?> showRenameClipDialog(
  BuildContext context, {
  required String initialTitle,
  AppAdaptiveModalVariant presentation = AppAdaptiveModalVariant.dialog,
}) {
  return showAppAdaptiveModal<String>(
    context: context,
    variant: presentation,
    drawerKey: const Key('rename-clip-bottom-sheet'),
    desktopWidth: context.appComponentTokens.playlistDialogWidth,
    mobileMaxHeightFactor: 0.5,
    builder: (_) => RenameClipDialog(initialTitle: initialTitle),
  );
}

class RenameClipDialog extends StatefulWidget {
  const RenameClipDialog({super.key, required this.initialTitle});

  final String initialTitle;

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
    return SingleChildScrollView(child: _buildContent(context));
  }

  Widget _buildContent(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final spacing = context.appSpacing;
    final isDrawer = AppAdaptiveModalShellScope.maybeIsDrawer(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.clipRenameTitle,
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
          hintText: l10n.clipRenameHint,
          textInputAction: TextInputAction.done,
          onFieldSubmitted: (_) => _submit(),
        ),
        SizedBox(height: spacing.md),
        AppModalActionRow(
          submitKey: const Key('rename-clip-submit-button'),
          submitLabel: l10n.commonSave,
          showCancel: false,
          equalWidth: isDrawer,
          onSubmit: _submit,
        ),
      ],
    );
  }
}
