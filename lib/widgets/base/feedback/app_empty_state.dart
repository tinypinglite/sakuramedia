import 'package:flutter/material.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/actions/app_button.dart';

class AppEmptyState extends StatelessWidget {
  const AppEmptyState({
    super.key,
    required this.message,
    this.icon,
    this.onRetry,
    this.retryLabel = '重试',
    this.retryKey,
  });

  final String message;
  final IconData? icon;
  final VoidCallback? onRetry;
  final String retryLabel;
  final Key? retryKey;

  @override
  Widget build(BuildContext context) {
    final spacing = context.appSpacing;
    final iconColor = resolveAppTextToneColor(context, AppTextTone.secondary);
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: spacing.lg,
        vertical: spacing.xxl,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              if (icon != null) ...[
                Icon(
                  icon,
                  size: context.appComponentTokens.iconSize4xl,
                  color: iconColor,
                ),
                SizedBox(height: spacing.md),
              ],
              Text(
                message,
                textAlign: TextAlign.center,
                style: resolveAppTextStyle(
                  context,
                  size: AppTextSize.s14,
                  weight: AppTextWeight.regular,
                  tone: AppTextTone.secondary,
                ),
              ),
              if (onRetry != null) ...[
                SizedBox(height: spacing.lg),
                AppButton(
                  key: retryKey,
                  label: retryLabel,
                  onPressed: onRetry,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
