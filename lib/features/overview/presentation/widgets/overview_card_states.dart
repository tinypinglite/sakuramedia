import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/l10n/app_localizations.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/actions/app_text_button.dart';

/// 概览卡片的统一错误行：一行说明 + 重试文字按钮。
class OverviewCardErrorRow extends StatelessWidget {
  const OverviewCardErrorRow({
    super.key,
    required this.message,
    this.onRetry,
    this.retryKey,
  });

  final String message;
  final VoidCallback? onRetry;
  final Key? retryKey;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            message,
            style: resolveAppTextStyle(
              context,
              size: AppTextSize.s12,
              weight: AppTextWeight.regular,
              tone: AppTextTone.secondary,
            ),
          ),
        ),
        if (onRetry != null) ...[
          SizedBox(width: context.appSpacing.sm),
          AppTextButton(
            label: AppLocalizations.of(context).commonRetry,
            size: AppTextButtonSize.small,
            labelKey: retryKey,
            onPressed: onRetry,
          ),
        ],
      ],
    );
  }
}
