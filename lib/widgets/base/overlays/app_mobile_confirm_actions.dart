import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/widgets/base/actions/app_button.dart';
import 'package:sakuramedia/widgets/base/l10n/app_l10n.dart';
import 'package:sakuramedia/widgets/base/overlays/app_modal_action_row.dart';

/// 移动端底部抽屉/弹窗的「取消 + 确认」双按钮底栏。
///
/// 统一布局：等宽两按钮；取消在左、确认在右。
/// `isDangerous: true` 时确认按钮为 danger，否则 primary。
/// `isLoading: true` 时确认按钮转圈、取消按钮自动禁用，避免提交中误关。
class AppMobileConfirmActions extends StatelessWidget {
  const AppMobileConfirmActions({
    super.key,
    required this.onCancel,
    required this.onConfirm,
    this.cancelLabel,
    this.confirmLabel,
    this.isDangerous = false,
    this.isLoading = false,
    this.cancelKey,
    this.confirmKey,
  });

  final VoidCallback? onCancel;
  final VoidCallback? onConfirm;
  final String? cancelLabel;
  final String? confirmLabel;
  final bool isDangerous;
  final bool isLoading;
  final Key? cancelKey;
  final Key? confirmKey;

  @override
  Widget build(BuildContext context) {
    final l10n = appL10n(context);
    return AppModalActionRow(
      cancelKey: cancelKey,
      submitKey: confirmKey,
      cancelLabel: cancelLabel ?? l10n.commonCancel,
      submitLabel: confirmLabel ?? l10n.baseConfirm,
      isSubmitting: isLoading,
      submitVariant: isDangerous
          ? AppButtonVariant.danger
          : AppButtonVariant.primary,
      onCancel: onCancel,
      onSubmit: onConfirm,
    );
  }
}
