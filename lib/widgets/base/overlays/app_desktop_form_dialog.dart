import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/actions/app_button.dart';
import 'package:sakuramedia/widgets/base/l10n/app_l10n.dart';

/// 桌面表单弹窗的正文。
///
/// 外层由 `showAppAdaptiveModal` 提供 `AppDesktopDialog`，本组件只负责表单、
/// 标题、可滚动内容与常驻的 Cancel/Save 动作区。
class AppDesktopFormDialog extends StatelessWidget {
  const AppDesktopFormDialog({
    super.key,
    required this.formKey,
    required this.title,
    required this.body,
    required this.onSubmit,
    this.submitKey,
    this.isSubmitting = false,
    this.isBusy = false,
    this.extraAction,
  });

  final GlobalKey<FormState> formKey;
  final String title;
  final Widget body;
  final VoidCallback? onSubmit;
  final Key? submitKey;
  final bool isSubmitting;
  final bool isBusy;

  /// 追加在 Save 后的操作，例如下载器配置测试。
  final Widget? extraAction;

  @override
  Widget build(BuildContext context) {
    final l10n = appL10n(context);
    final spacing = context.appSpacing;
    return Form(
      key: formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: resolveAppTextStyle(
              context,
              size: AppTextSize.s18,
              weight: AppTextWeight.semibold,
              tone: AppTextTone.primary,
            ),
          ),
          SizedBox(height: spacing.xl),
          Flexible(child: SingleChildScrollView(child: body)),
          SizedBox(height: spacing.xl),
          PopScope(
            canPop: !isSubmitting,
            child: Row(
              children: [
                Expanded(
                  child: AppButton(
                    onPressed: isBusy
                        ? null
                        : () => Navigator.of(context).pop(),
                    label: l10n.commonCancel,
                  ),
                ),
                SizedBox(width: spacing.md),
                Expanded(
                  child: AppButton(
                    key: submitKey,
                    onPressed: isBusy ? null : onSubmit,
                    label: l10n.commonSave,
                    variant: AppButtonVariant.primary,
                    isLoading: isSubmitting,
                  ),
                ),
                if (extraAction != null) ...[
                  SizedBox(width: spacing.md),
                  Expanded(child: extraAction!),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
