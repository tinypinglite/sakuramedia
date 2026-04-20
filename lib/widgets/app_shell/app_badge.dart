import 'package:flutter/material.dart';
import 'package:sakuramedia/theme.dart';

enum AppBadgeTone { neutral, primary, info, warning, error, success }

enum AppBadgeSize { compact, regular }

class AppBadge extends StatelessWidget {
  const AppBadge({
    super.key,
    required this.label,
    this.tone = AppBadgeTone.neutral,
    this.size = AppBadgeSize.regular,
  });

  final String label;
  final AppBadgeTone tone;
  final AppBadgeSize size;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final spacing = context.appSpacing;
    final (backgroundColor, foregroundColor) = switch (tone) {
      AppBadgeTone.neutral => (
        colors.surfaceMuted,
        context.appTextPalette.secondary,
      ),
      AppBadgeTone.primary => (
        colors.selectionSurface,
        context.appTextPalette.accent,
      ),
      AppBadgeTone.info => (colors.infoSurface, context.appTextPalette.info),
      AppBadgeTone.warning => (
        colors.warningSurface,
        context.appTextPalette.warning,
      ),
      AppBadgeTone.error => (colors.errorSurface, context.appTextPalette.error),
      AppBadgeTone.success => (
        colors.successSurface,
        context.appTextPalette.success,
      ),
    };
    final verticalPadding =
        size == AppBadgeSize.compact ? spacing.xs / 2 : spacing.xs;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: spacing.sm,
        vertical: verticalPadding,
      ),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: context.appRadius.pillBorder,
      ),
      child: Text(
        label,
        style: resolveAppTextStyle(
          context,
          size: AppTextSize.s10,
          weight: AppTextWeight.regular,
          tone: AppTextTone.muted,
        ).copyWith(color: foregroundColor),
      ),
    );
  }
}
