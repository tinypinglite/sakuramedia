import 'package:flutter/material.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/actions/app_button.dart';

/// 装进 [showAppBottomDrawer] 的表单外壳。
///
/// 承担四处 mobile 编辑抽屉共有的外壳结构：`SingleChildScrollView` → `Form` →
/// 标题 + 可选副标题 + [body] slot + Cancel/Submit 双按钮。键盘 inset 由
/// [AppBottomDrawerSurface] 在抽屉外壳层统一兜底（`AnimatedPadding(viewInsets)`），
/// 此处不再自补偿，避免双 padding。
///
/// [body] 由调用方组装 —— 通常是 FormFields，也可以在其后追加探针 chips 之类
/// 附加控件（如 downloaders 页会追加 `DownloadClientEditorProbeChips`）。
class AppBottomFormSheet extends StatelessWidget {
  const AppBottomFormSheet({
    super.key,
    required this.formKey,
    required this.title,
    this.subtitle,
    required this.body,
    required this.submitKey,
    required this.isSubmitting,
    required this.onSubmit,
    this.cancelLabel = '取消',
    this.submitLabel = '保存',
    this.submitDisabled = false,
  });

  final GlobalKey<FormState> formKey;
  final String title;
  final String? subtitle;

  /// 表单主体：一般是 FormFields；可在其内部自行追加探针 chips 等附加控件。
  final Widget body;

  /// 提交按钮 Key —— 必填，测试用。
  final Key submitKey;

  final String cancelLabel;
  final String submitLabel;

  /// 驱动提交按钮的 spinner。同时会禁用取消按钮防误关。
  final bool isSubmitting;

  /// 独立门控：即使 `!isSubmitting` 也可让提交禁用（如探针检测进行中）。
  final bool submitDisabled;

  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final spacing = context.appSpacing;
    final busy = isSubmitting || submitDisabled;
    final resolvedSubtitle = subtitle;

    return SingleChildScrollView(
      child: Form(
        key: formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              title,
              style: resolveAppTextStyle(
                context,
                size: AppTextSize.s16,
                weight: AppTextWeight.semibold,
                tone: AppTextTone.primary,
              ),
            ),
            if (resolvedSubtitle != null) ...[
              SizedBox(height: spacing.xs),
              Text(
                resolvedSubtitle,
                style: resolveAppTextStyle(
                  context,
                  size: AppTextSize.s12,
                  weight: AppTextWeight.regular,
                  tone: AppTextTone.secondary,
                ),
              ),
            ],
            SizedBox(height: spacing.lg),
            body,
            SizedBox(height: spacing.lg),
            Row(
              children: [
                Expanded(
                  child: AppButton(
                    label: cancelLabel,
                    onPressed:
                        busy ? null : () => Navigator.of(context).pop(),
                  ),
                ),
                SizedBox(width: spacing.md),
                Expanded(
                  child: AppButton(
                    key: submitKey,
                    label: submitLabel,
                    variant: AppButtonVariant.primary,
                    isLoading: isSubmitting,
                    onPressed: submitDisabled ? null : onSubmit,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
