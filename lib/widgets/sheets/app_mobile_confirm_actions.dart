import 'package:flutter/material.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/actions/app_button.dart';

/// 移动端底部抽屉/弹窗的「取消 + 确认」双按钮底栏。
///
/// 统一布局：等宽两按钮 + 间距 `md`。取消在左、确认在右；
/// `isDangerous: true` 时确认按钮为 danger，否则 primary。
/// `isLoading: true` 时确认按钮转圈、取消按钮自动禁用，避免提交中误关。
class AppMobileConfirmActions extends StatelessWidget {
  const AppMobileConfirmActions({
    super.key,
    required this.onCancel,
    required this.onConfirm,
    this.cancelLabel = '取消',
    this.confirmLabel = '确认',
    this.isDangerous = false,
    this.isLoading = false,
    this.cancelKey,
    this.confirmKey,
  });

  final VoidCallback? onCancel;
  final VoidCallback? onConfirm;
  final String cancelLabel;
  final String confirmLabel;
  final bool isDangerous;
  final bool isLoading;
  final Key? cancelKey;
  final Key? confirmKey;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: AppButton(
            key: cancelKey,
            label: cancelLabel,
            onPressed: isLoading ? null : onCancel,
          ),
        ),
        SizedBox(width: context.appSpacing.md),
        Expanded(
          child: AppButton(
            key: confirmKey,
            label: confirmLabel,
            variant:
                isDangerous
                    ? AppButtonVariant.danger
                    : AppButtonVariant.primary,
            isLoading: isLoading,
            onPressed: onConfirm,
          ),
        ),
      ],
    );
  }
}
