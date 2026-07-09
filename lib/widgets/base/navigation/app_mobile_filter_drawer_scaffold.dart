import 'package:flutter/material.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/actions/app_button.dart';
import 'package:sakuramedia/widgets/base/actions/app_text_button.dart';

/// 移动端筛选底部抽屉的通用壳层：
///   标题行（左标题 + 右「重置」文字按钮）
///   分隔线
///   可滚动内容区
///   底部固定全宽「确定」主按钮
///
/// 「确定才生效」模式：调用方在 [onConfirm] 里 Navigator.pop(本地副本)。
/// [onReset] 为 null 时「重置」按钮置灰禁用。
class AppMobileFilterDrawerScaffold extends StatelessWidget {
  const AppMobileFilterDrawerScaffold({
    super.key,
    required this.title,
    required this.onReset,
    required this.onConfirm,
    required this.child,
    this.confirmLabel = '确定',
    this.resetLabel = '重置',
    this.resetButtonKey,
    this.confirmButtonKey,
  });

  final String title;
  final VoidCallback? onReset;
  final VoidCallback onConfirm;
  final Widget child;
  final String confirmLabel;
  final String resetLabel;
  final Key? resetButtonKey;
  final Key? confirmButtonKey;

  @override
  Widget build(BuildContext context) {
    final spacing = context.appSpacing;
    final colors = context.appColors;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: EdgeInsets.symmetric(vertical: spacing.xs),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: resolveAppTextStyle(
                    context,
                    size: AppTextSize.s16,
                    weight: AppTextWeight.semibold,
                    tone: AppTextTone.primary,
                  ),
                ),
              ),
              AppTextButton(
                key: resetButtonKey,
                label: resetLabel,
                size: AppTextButtonSize.small,
                onPressed: onReset,
              ),
            ],
          ),
        ),
        SizedBox(height: spacing.sm),
        Divider(height: 1, color: colors.divider),
        Flexible(
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(vertical: spacing.md),
            child: child,
          ),
        ),
        Divider(height: 1, color: colors.divider),
        SafeArea(
          top: false,
          minimum: EdgeInsets.only(top: spacing.md, bottom: spacing.sm),
          child: AppButton(
            key: confirmButtonKey,
            label: confirmLabel,
            variant: AppButtonVariant.primary,
            onPressed: onConfirm,
          ),
        ),
      ],
    );
  }
}
