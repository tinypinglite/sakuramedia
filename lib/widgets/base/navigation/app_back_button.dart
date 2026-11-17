import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/actions/app_glass_icon_button.dart';
import 'package:sakuramedia/widgets/base/actions/app_icon_button.dart';
import 'package:sakuramedia/widgets/base/l10n/app_l10n.dart';
import 'package:sakuramedia/widgets/base/layout/surface/app_surface_style.dart';

enum AppBackButtonVariant { solid, glass, mediaOverlay }

enum AppBackButtonSize { compact, toolbar, touch }

/// 共享返回按钮。
///
/// 尺寸矩阵：
/// - [AppBackButtonSize.compact]：28 / 20；
/// - [AppBackButtonSize.toolbar]：实色 28 / 20，玻璃 32 / 16；
/// - [AppBackButtonSize.touch]：44 / 20；
/// - [AppBackButtonVariant.mediaOverlay]：44 / 20，并使用媒体前景色。
///
/// 生产入口统一使用 [AppBackButtonVariant.glass] 的 `control` 常驻胶囊；
/// 高对比度模式下回退为实色按钮。
class AppBackButton extends StatelessWidget {
  const AppBackButton({
    super.key,
    required this.onPressed,
    this.variant = AppBackButtonVariant.glass,
    this.size = AppBackButtonSize.toolbar,
    this.overlay = false,
    this.tooltip,
    this.semanticLabel,
    this.glassTone = AppGlassTone.standard,
  });

  static const IconData icon = Icons.arrow_back_ios_new_rounded;

  final VoidCallback onPressed;
  final AppBackButtonVariant variant;
  final AppBackButtonSize size;

  /// 覆盖在媒体上时使用 `onMedia` 前景色。
  final bool overlay;
  final String? tooltip;
  final String? semanticLabel;
  final AppGlassTone glassTone;

  @override
  Widget build(BuildContext context) {
    final l10n = appL10n(context);
    final resolvedTooltip = tooltip ?? l10n.shellBack;
    final resolvedSemanticLabel = semanticLabel ?? tooltip ?? l10n.shellBack;
    final highContrast = MediaQuery.maybeHighContrastOf(context) ?? false;

    if (variant == AppBackButtonVariant.glass) {
      final (buttonSize, iconSize) = switch (size) {
        AppBackButtonSize.compact => (28.0, 20.0),
        AppBackButtonSize.toolbar => (32.0, 16.0),
        AppBackButtonSize.touch => (44.0, 20.0),
      };
      if (highContrast) {
        return AppIconButton(
          tooltip: resolvedTooltip,
          semanticLabel: resolvedSemanticLabel,
          onPressed: onPressed,
          padding: EdgeInsets.zero,
          size: buttonSize >= 40
              ? AppIconButtonSize.regular
              : AppIconButtonSize.compact,
          iconColor: overlay
              ? context.appTextPalette.onMedia
              : context.appTextPalette.primary,
          backgroundColor: overlay
              ? context.appColors.mediaOverlayStrong
              : context.appColors.surfaceElevated,
          borderColor: overlay
              ? context.appColors.mediaOverlayBorder
              : context.appColors.borderStrong,
          borderRadius: context.appRadius.pillBorder,
          icon: Icon(icon, size: iconSize),
        );
      }
      return DecoratedBox(
        position: DecorationPosition.foreground,
        decoration: BoxDecoration(
          borderRadius: context.appRadius.pillBorder,
          border: Border.all(color: context.appColors.borderSubtle),
        ),
        child: AppGlassIconButton(
          tooltip: resolvedTooltip,
          semanticLabel: resolvedSemanticLabel,
          icon: icon,
          iconSize: iconSize,
          size: buttonSize,
          foregroundColor: overlay ? context.appTextPalette.onMedia : null,
          tone: glassTone,
          onPressed: onPressed,
        ),
      );
    }

    final isMediaOverlay = variant == AppBackButtonVariant.mediaOverlay;
    final buttonSize = isMediaOverlay
        ? AppIconButtonSize.regular
        : switch (size) {
            AppBackButtonSize.compact => AppIconButtonSize.compact,
            AppBackButtonSize.toolbar => AppIconButtonSize.compact,
            AppBackButtonSize.touch => AppIconButtonSize.regular,
          };
    final resolvedIconSize = isMediaOverlay
        ? 20.0
        : switch (size) {
            AppBackButtonSize.compact => 20.0,
            AppBackButtonSize.toolbar => 20.0,
            AppBackButtonSize.touch => 20.0,
          };
    return AppIconButton(
      tooltip: resolvedTooltip,
      semanticLabel: resolvedSemanticLabel,
      onPressed: onPressed,
      padding: EdgeInsets.zero,
      size: buttonSize,
      iconColor: isMediaOverlay || overlay
          ? context.appTextPalette.onMedia
          : null,
      icon: Icon(icon, size: resolvedIconSize),
    );
  }
}
