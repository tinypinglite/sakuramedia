import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/actions/app_button.dart';
import 'package:sakuramedia/widgets/base/l10n/app_l10n.dart';

/// 弹层底部动作行：取消在左、提交在右，默认等宽。
///
/// 提交中会禁用取消并让提交按钮转圈；有 [extraAction] 时三项等分。
class AppModalActionRow extends StatelessWidget {
  const AppModalActionRow({
    super.key,
    required this.onCancel,
    required this.onSubmit,
    this.cancelLabel,
    this.submitLabel,
    this.isSubmitting = false,
    this.submitDisabled = false,
    this.submitVariant = AppButtonVariant.primary,
    this.equalWidth = true,
    this.cancelKey,
    this.submitKey,
    this.extraAction,
  });

  final VoidCallback? onCancel;
  final VoidCallback? onSubmit;
  final String? cancelLabel;
  final String? submitLabel;
  final bool isSubmitting;
  final bool submitDisabled;
  final AppButtonVariant submitVariant;
  final bool equalWidth;
  final Key? cancelKey;
  final Key? submitKey;
  final Widget? extraAction;

  @override
  Widget build(BuildContext context) {
    final l10n = appL10n(context);
    final spacing = context.appSpacing;
    final buttons = <Widget>[
      AppButton(
        key: cancelKey,
        label: cancelLabel ?? l10n.commonCancel,
        onPressed: isSubmitting ? null : onCancel,
      ),
      AppButton(
        key: submitKey,
        label: submitLabel ?? l10n.baseConfirm,
        variant: submitVariant,
        isLoading: isSubmitting,
        onPressed: submitDisabled ? null : onSubmit,
      ),
      ?extraAction,
    ];

    if (!equalWidth) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          for (var i = 0; i < buttons.length; i++) ...[
            if (i > 0) SizedBox(width: spacing.md),
            buttons[i],
          ],
        ],
      );
    }
    return Row(
      children: [
        for (var i = 0; i < buttons.length; i++) ...[
          if (i > 0) SizedBox(width: spacing.md),
          Expanded(child: buttons[i]),
        ],
      ],
    );
  }
}
