import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/actions/app_button.dart';
import 'package:sakuramedia/widgets/base/l10n/app_l10n.dart';

enum AppInlineErrorTone {
  /// 中性提示：数据加载失败但页面可继续使用。
  neutral,

  /// 强错误：当前操作/表单提交失败。
  error,
}

/// 内联错误提示条：错误图标 + 说明文字 + 可选重试按钮。
///
/// 用于「某段数据加载失败但仍可继续使用页面」的场景，例如榜单筛选元数据
/// 加载失败。整块内容不可用的错误用 `AppSectionError` / `AppEmptyState`。
class AppInlineErrorBanner extends StatelessWidget {
  const AppInlineErrorBanner({
    super.key,
    required this.message,
    this.onRetry,
    this.retryKey,
    this.tone = AppInlineErrorTone.neutral,
  });

  final String message;
  final Future<void> Function()? onRetry;
  final Key? retryKey;
  final AppInlineErrorTone tone;

  @override
  Widget build(BuildContext context) {
    final l10n = appL10n(context);
    final isError = tone == AppInlineErrorTone.error;
    final foreground = isError
        ? context.appTextPalette.error
        : context.appTextPalette.secondary;
    final onRetry = this.onRetry;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: isError
            ? context.appColors.errorSurface
            : context.appColors.surfaceMuted,
        borderRadius: context.appRadius.mdBorder,
        border: isError
            ? null
            : Border.all(color: context.appColors.borderSubtle),
      ),
      child: Padding(
        padding: EdgeInsets.all(context.appSpacing.md),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.error_outline_rounded,
              size: context.appComponentTokens.iconSizeXl,
              color: foreground,
            ),
            SizedBox(width: context.appSpacing.sm),
            Expanded(
              child: Text(
                message,
                style: resolveAppTextStyle(
                  context,
                  size: AppTextSize.s12,
                  weight: AppTextWeight.regular,
                  tone: isError ? AppTextTone.error : AppTextTone.secondary,
                ),
              ),
            ),
            if (onRetry != null) ...[
              SizedBox(width: context.appSpacing.sm),
              AppButton(
                key: retryKey,
                label: l10n.commonRetry,
                size: AppButtonSize.xSmall,
                variant: AppButtonVariant.secondary,
                onPressed: () => unawaited(onRetry()),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
