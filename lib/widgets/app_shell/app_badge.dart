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
    final theme = Theme.of(context);
    final spacing = context.appSpacing;
    final (backgroundColor, foregroundColor) = switch (tone) {
      AppBadgeTone.neutral => (colors.surfaceMuted, colors.textSecondary),
      AppBadgeTone.primary => (colors.selectionSurface, colors.selectionForeground),
      AppBadgeTone.info => (colors.infoSurface, colors.infoForeground),
      AppBadgeTone.warning => (colors.warningSurface, colors.warningForeground),
      AppBadgeTone.error => (colors.errorSurface, colors.errorForeground),
      AppBadgeTone.success => (colors.successSurface, colors.successForeground),
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
        style: theme.textTheme.labelSmall?.copyWith(
          color: foregroundColor,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
