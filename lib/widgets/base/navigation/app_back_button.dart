import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/actions/app_glass_icon_button.dart';
import 'package:sakuramedia/widgets/base/actions/app_icon_button.dart';
import 'package:sakuramedia/widgets/base/l10n/app_l10n.dart';

enum AppBackButtonVariant { solid, glass, mediaOverlay }

enum AppBackButtonSize { compact, toolbar, touch }

/// 共享返回按钮。
///
/// 尺寸矩阵：
/// - [AppBackButtonSize.compact]：28 / 20；
/// - [AppBackButtonSize.toolbar]：实色 28 / 20，玻璃 32 / 16；
/// - [AppBackButtonSize.touch]：44 / 20；
/// - [AppBackButtonVariant.mediaOverlay]：44 / 18，并使用媒体前景色。
///
/// 高对比度模式下玻璃变体回退为实色按钮。
class AppBackButton extends StatelessWidget {
  const AppBackButton({
    super.key,
    required this.onPressed,
    this.variant = AppBackButtonVariant.solid,
    this.size = AppBackButtonSize.toolbar,
    this.overlay = false,
    this.tooltip,
    this.semanticLabel,
  });

  static const IconData icon = Icons.arrow_back_ios_new_rounded;

  final VoidCallback onPressed;
  final AppBackButtonVariant variant;
  final AppBackButtonSize size;

  /// 实色按钮使用媒体前景色，用于压在封面/播放器等内容上。
  final bool overlay;
  final String? tooltip;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final l10n = appL10n(context);
    final resolvedTooltip = tooltip ?? l10n.shellBack;
    final resolvedSemanticLabel = semanticLabel ?? tooltip ?? l10n.shellBack;
    final highContrast = MediaQuery.maybeHighContrastOf(context) ?? false;

    if (variant == AppBackButtonVariant.glass && !highContrast) {
      final (buttonSize, iconSize) = switch (size) {
        AppBackButtonSize.compact => (28.0, 20.0),
        AppBackButtonSize.toolbar => (32.0, 16.0),
        AppBackButtonSize.touch => (44.0, 20.0),
      };
      return AppGlassIconButton(
        tooltip: resolvedTooltip,
        semanticLabel: resolvedSemanticLabel,
        icon: icon,
        iconSize: iconSize,
        size: buttonSize,
        foregroundColor: overlay ? context.appTextPalette.onMedia : null,
        onPressed: onPressed,
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
        ? 18.0
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
