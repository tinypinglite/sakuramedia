import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/interaction/app_interactive_surface.dart';

/// 筛选面板里的多选胶囊。
///
/// 与单选分段控件使用同一套中性选中态；不做背景模糊，避免标签云里几百个
/// chip 叠成大量玻璃层。交互反馈沿用项目统一的 [AppInteractiveSurface]。
class AppFilterChip extends StatelessWidget {
  const AppFilterChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onPressed,
    this.enabled = true,
    this.trailing,
    this.semanticLabel,
    this.labelKey,
    this.maxWidth,
  });

  final String label;
  final bool selected;
  final VoidCallback? onPressed;
  final bool enabled;
  final Widget? trailing;
  final String? semanticLabel;
  final Key? labelKey;
  final double? maxWidth;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final tokens = context.appComponentTokens;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final tone = selected ? AppTextTone.primary : AppTextTone.secondary;
    final foreground = resolveAppTextToneColor(context, tone);
    final interactive = enabled && onPressed != null;
    final backgroundColor = selected
        ? (isDark
              ? context.appColors.mediaOverlayBorder.withValues(alpha: 0.24)
              : colors.surfaceElevated)
        : (isDark
              ? context.appColors.mediaOverlaySoft
              : colors.surfaceMuted.withValues(alpha: 0.55));
    final chip = Container(
      constraints: BoxConstraints(
        minHeight: tokens.buttonHeightXs + context.appSpacing.xs,
        maxWidth: maxWidth ?? double.infinity,
      ),
      padding: EdgeInsets.symmetric(
        horizontal: context.appSpacing.md,
        vertical: context.appSpacing.xs + 2,
      ),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: context.appRadius.pillBorder,
        border: Border.all(
          color: selected
              ? colors.borderStrong
              : colors.borderSubtle.withValues(alpha: 0.6),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: Text(
              key: labelKey,
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: resolveAppTextStyle(
                context,
                size: AppTextSize.s12,
                weight: selected
                    ? AppTextWeight.semibold
                    : AppTextWeight.regular,
                tone: tone,
              ),
            ),
          ),
          if (trailing != null) ...[
            SizedBox(width: context.appSpacing.xs),
            IconTheme(
              data: IconThemeData(size: tokens.iconSize2xs, color: foreground),
              child: trailing!,
            ),
          ],
        ],
      ),
    );

    return Semantics(
      selected: selected,
      button: true,
      enabled: interactive,
      label: semanticLabel ?? label,
      child: Opacity(
        opacity: enabled ? 1 : 0.56,
        child: AppInteractiveSurface(
          enabled: interactive,
          onTap: onPressed,
          excludeFromSemantics: true,
          child: chip,
        ),
      ),
    );
  }
}
