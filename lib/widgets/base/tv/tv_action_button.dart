import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/tv/tv_focusable.dart';

enum TvActionButtonTone { primary, secondary }

class TvActionButton extends StatelessWidget {
  const TvActionButton({
    super.key,
    required this.label,
    this.icon,
    this.onPressed,
    this.autofocus = false,
    this.tone = TvActionButtonTone.primary,
  });

  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final bool autofocus;
  final TvActionButtonTone tone;

  @override
  Widget build(BuildContext context) {
    final primary = tone == TvActionButtonTone.primary;
    final foreground = primary
        ? Theme.of(context).colorScheme.onPrimary
        : context.appTextPalette.primary;
    final background = primary
        ? Theme.of(context).colorScheme.primary
        : context.appColors.surfaceElevated;
    return TvFocusable(
      onPressed: onPressed,
      autofocus: autofocus,
      borderRadius: context.appRadius.mdBorder,
      child: Container(
        height: AppTvTokens.actionHeight,
        constraints: const BoxConstraints(minWidth: AppTvTokens.actionMinWidth),
        padding: EdgeInsets.symmetric(horizontal: context.appSpacing.xl),
        decoration: BoxDecoration(
          color: background,
          borderRadius: context.appRadius.mdBorder,
          border: primary
              ? null
              : Border.all(color: context.appColors.borderStrong),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null) ...[
              Icon(
                icon,
                color: foreground,
                size: context.appComponentTokens.iconSizeXl,
              ),
              SizedBox(width: context.appSpacing.sm),
            ],
            Text(
              label,
              style: resolveAppTextStyle(
                context,
                size: AppTextSize.s20,
                weight: AppTextWeight.semibold,
                tone: primary ? AppTextTone.onMedia : AppTextTone.primary,
              ).copyWith(color: foreground),
            ),
          ],
        ),
      ),
    );
  }
}
