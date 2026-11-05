import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/theme.dart';

@immutable
class OverviewSurfaceStyle {
  const OverviewSurfaceStyle({
    required this.gradient,
    required this.borderColor,
    required this.glowColor,
  });

  final List<Color> gradient;
  final Color borderColor;
  final Color glowColor;

  static OverviewSurfaceStyle resolve(
    BuildContext context, {
    OverviewSurfaceTone tone = OverviewSurfaceTone.primary,
  }) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isDarkTheme = theme.brightness == Brightness.dark;
    final primary = HSLColor.fromColor(scheme.primary);
    final secondary = HSLColor.fromColor(scheme.secondary);
    final (
      startLightness,
      endLightness,
      saturationScale,
      glowAlpha,
    ) = switch (tone) {
      OverviewSurfaceTone.primary => (
        isDarkTheme ? 0.17 : 0.14,
        isDarkTheme ? 0.22 : 0.19,
        0.78,
        0.34,
      ),
      OverviewSurfaceTone.insight => (
        isDarkTheme ? 0.21 : 0.175,
        isDarkTheme ? 0.26 : 0.225,
        0.72,
        0.22,
      ),
    };
    final start = _deriveSurfaceColor(
      primary,
      lightness: startLightness,
      saturationScale: saturationScale,
    );
    final end = _deriveSurfaceColor(
      secondary,
      lightness: endLightness,
      saturationScale: saturationScale * 0.88,
    );
    return OverviewSurfaceStyle(
      gradient: <Color>[start, Color.lerp(start, end, 0.58)!, end],
      borderColor: scheme.primary.withValues(
        alpha: tone == OverviewSurfaceTone.primary ? 0.24 : 0.20,
      ),
      glowColor: scheme.primary.withValues(alpha: glowAlpha),
    );
  }
}

/// 概览页两级主题面：主行更深，下方洞察行略浅一档。
enum OverviewSurfaceTone { primary, insight }

Color _deriveSurfaceColor(
  HSLColor base, {
  required double lightness,
  required double saturationScale,
}) {
  return base
      .withLightness(lightness.clamp(0, 1).toDouble())
      .withSaturation(
        (base.saturation * saturationScale).clamp(0, 1).toDouble(),
      )
      .toColor();
}

/// 主题色推导的概览视觉面，不引入固定卡片色。
class OverviewSurface extends StatelessWidget {
  const OverviewSurface({
    super.key,
    required this.child,
    this.padding,
    this.tone = OverviewSurfaceTone.primary,
    this.minHeight,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final OverviewSurfaceTone tone;
  final double? minHeight;

  @override
  Widget build(BuildContext context) {
    final style = OverviewSurfaceStyle.resolve(context, tone: tone);
    final spacing = context.appSpacing;
    final radius = context.appRadius.lgBorder;
    final glowSize = spacing.xxxl * 9;

    return Container(
      width: double.infinity,
      constraints: minHeight == null
          ? null
          : BoxConstraints(minHeight: minHeight!),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: radius,
        border: Border.all(color: style.borderColor),
      ),
      child: Stack(
        children: <Widget>[
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: style.gradient,
                ),
              ),
            ),
          ),
          Positioned(
            top: -glowSize * 0.44,
            right: -glowSize * 0.20,
            child: IgnorePointer(
              child: SizedBox(
                width: glowSize,
                height: glowSize,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: <Color>[
                        style.glowColor,
                        style.glowColor.withValues(alpha: 0),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          Padding(padding: padding ?? EdgeInsets.all(spacing.xl), child: child),
        ],
      ),
    );
  }
}
