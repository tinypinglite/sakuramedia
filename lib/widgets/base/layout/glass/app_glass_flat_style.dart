import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/theme.dart';

enum AppFlatSurfaceRole {
  surface,
  overlay,
  input,
  popover,
  toolbarControl,
  toolbarInput,
  bar,
  mediaOverlay,
  buttonFilled,
  buttonProminent,
}

class AppFlatGlassRecipe {
  const AppFlatGlassRecipe({
    required this.fill,
    required this.border,
    required this.highlight,
    required this.highContrast,
  });

  final Color fill;
  final Color border;
  final Color highlight;
  final bool highContrast;
}

/// 扁平风格的固定配方：无模糊、无 shader、无阴影。
abstract final class AppGlassFlatStyle {
  static AppFlatGlassRecipe recipe(
    BuildContext context,
    AppFlatSurfaceRole role,
  ) {
    final highContrast = MediaQuery.maybeHighContrastOf(context) ?? false;
    final colors = context.appColors;
    if (highContrast) {
      if (role == AppFlatSurfaceRole.mediaOverlay) {
        return AppFlatGlassRecipe(
          fill: colors.mediaOverlayStrong,
          border: colors.highlight.withValues(alpha: 0.38),
          highlight: colors.highlight.withValues(alpha: 0),
          highContrast: true,
        );
      }
      return AppFlatGlassRecipe(
        fill: colors.surfaceElevated,
        border: colors.borderStrong,
        highlight: colors.highlight.withValues(alpha: 0),
        highContrast: true,
      );
    }

    final primary = Theme.of(context).colorScheme.primary;
    final highlight = context.appTextPalette.onMedia;
    return switch (role) {
      AppFlatSurfaceRole.surface => AppFlatGlassRecipe(
        fill: colors.surfaceElevated.withValues(alpha: 0.94),
        border: colors.borderSubtle,
        highlight: highlight.withValues(alpha: 0.04),
        highContrast: false,
      ),
      AppFlatSurfaceRole.overlay => AppFlatGlassRecipe(
        fill: colors.surfaceElevated.withValues(alpha: 0.97),
        border: colors.borderSubtle,
        highlight: highlight.withValues(alpha: 0.04),
        highContrast: false,
      ),
      AppFlatSurfaceRole.popover => AppFlatGlassRecipe(
        fill: colors.surfaceElevated.withValues(alpha: 0.96),
        border: colors.borderSubtle,
        highlight: highlight.withValues(alpha: 0.05),
        highContrast: false,
      ),
      AppFlatSurfaceRole.input => AppFlatGlassRecipe(
        fill: colors.surfaceElevated.withValues(alpha: 0.94),
        border: colors.borderSubtle,
        highlight: highlight.withValues(alpha: 0.03),
        highContrast: false,
      ),
      AppFlatSurfaceRole.toolbarInput => AppFlatGlassRecipe(
        fill: colors.surfaceMuted.withValues(alpha: 0.88),
        border: colors.borderSubtle,
        highlight: highlight.withValues(alpha: 0.03),
        highContrast: false,
      ),
      AppFlatSurfaceRole.bar => AppFlatGlassRecipe(
        fill: colors.surfaceElevated.withValues(alpha: 0.94),
        border: colors.borderSubtle,
        highlight: highlight.withValues(alpha: 0.05),
        highContrast: false,
      ),
      AppFlatSurfaceRole.mediaOverlay => AppFlatGlassRecipe(
        fill: colors.mediaOverlayStrong.withValues(alpha: 0.82),
        border: colors.highlight.withValues(alpha: 0.18),
        highlight: colors.highlight.withValues(alpha: 0.06),
        highContrast: false,
      ),
      AppFlatSurfaceRole.buttonFilled => AppFlatGlassRecipe(
        fill: colors.surfaceElevated.withValues(alpha: 0.90),
        border: colors.borderSubtle,
        highlight: highlight.withValues(alpha: 0.03),
        highContrast: false,
      ),
      AppFlatSurfaceRole.toolbarControl => AppFlatGlassRecipe(
        fill: colors.surfaceElevated.withValues(alpha: 0.86),
        border: colors.borderSubtle,
        highlight: highlight.withValues(alpha: 0.04),
        highContrast: false,
      ),
      AppFlatSurfaceRole.buttonProminent => AppFlatGlassRecipe(
        fill: primary.withValues(alpha: 0.16),
        border: primary.withValues(alpha: 0.28),
        highlight: highlight.withValues(alpha: 0.06),
        highContrast: false,
      ),
    };
  }
}
