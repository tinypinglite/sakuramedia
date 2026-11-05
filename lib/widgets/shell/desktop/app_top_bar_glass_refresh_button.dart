import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/l10n/app_localizations.dart';
import 'package:sakuramedia/theme.dart';

/// 概览透明顶栏右侧的液态玻璃刷新按钮。
class AppTopBarGlassRefreshButton extends StatelessWidget {
  const AppTopBarGlassRefreshButton({
    super.key,
    required this.onPressed,
    this.isRefreshing = false,
  });

  static const double size = 32;
  static const double iconSize = 18;

  final VoidCallback onPressed;
  final bool isRefreshing;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final iconColor = context.appTextPalette.primary;
    return Tooltip(
      message: l10n.commonRefresh,
      child: GlassIconButton(
        key: Key(
          isRefreshing
              ? 'topbar-refresh-button-loading'
              : 'topbar-refresh-button',
        ),
        icon: isRefreshing
            ? SizedBox(
                width: iconSize,
                height: iconSize,
                child: CircularProgressIndicator.adaptive(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color?>(iconColor),
                ),
              )
            : Icon(Icons.refresh_rounded, color: iconColor),
        iconSize: iconSize,
        onPressed: isRefreshing ? null : onPressed,
        size: size,
        semanticLabel: l10n.commonRefresh,
        settings: _glassSettings(context),
        quality: GlassQuality.standard,
        useOwnLayer: true,
      ),
    );
  }

  LiquidGlassSettings _glassSettings(BuildContext context) {
    return LiquidGlassSettings(
      thickness: 18,
      blur: 8,
      saturation: 1.25,
      chromaticAberration: 0.01,
      lightIntensity: 0.5,
      glassColor: context.appColors.surfaceElevated.withValues(alpha: 0.22),
      shadowElevation: 0,
    );
  }
}
