import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/l10n/app_localizations.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/actions/app_text_button.dart';
import 'package:sakuramedia/widgets/base/interaction/app_interactive_surface.dart';

/// 概览卡片的统一错误行：一行说明 + 重试文字按钮。
class OverviewCardErrorRow extends StatelessWidget {
  const OverviewCardErrorRow({
    super.key,
    required this.message,
    this.onRetry,
    this.retryKey,
    this.onDark = false,
  });

  final String message;
  final VoidCallback? onRetry;
  final Key? retryKey;
  final bool onDark;

  @override
  Widget build(BuildContext context) {
    if (onDark) {
      return Row(
        children: [
          Expanded(
            child: Text(
              message,
              style:
                  resolveAppTextStyle(
                    context,
                    size: AppTextSize.s12,
                    tone: AppTextTone.onMedia,
                  ).copyWith(
                    color: context.appTextPalette.onMedia.withValues(
                      alpha: 0.78,
                    ),
                  ),
            ),
          ),
          if (onRetry != null) ...[
            SizedBox(width: context.appSpacing.sm),
            AppInteractiveSurface(
              onTap: onRetry,
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: context.appSpacing.sm,
                  vertical: context.appSpacing.xs,
                ),
                child: Text(
                  AppLocalizations.of(context).commonRetry,
                  key: retryKey,
                  style: resolveAppTextStyle(
                    context,
                    size: AppTextSize.s12,
                    weight: AppTextWeight.semibold,
                    tone: AppTextTone.onMedia,
                  ),
                ),
              ),
            ),
          ],
        ],
      );
    }
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
