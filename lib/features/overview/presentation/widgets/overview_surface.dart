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
    final base = context.appColors.surfaceCard;
    final isPrimary = tone == OverviewSurfaceTone.primary;
    final start = Color.alphaBlend(
      scheme.primary.withValues(alpha: isPrimary ? 0.075 : 0.045),
      base,
    );
    final end = Color.alphaBlend(
      scheme.secondary.withValues(alpha: isPrimary ? 0.115 : 0.075),
      base,
    );
    return OverviewSurfaceStyle(
      gradient: <Color>[start, Color.lerp(start, end, 0.58)!, end],
      borderColor: scheme.primary.withValues(alpha: 0.16),
      glowColor: scheme.primary.withValues(alpha: isPrimary ? 0.10 : 0.06),
    );
  }
}

/// 概览页两级主题面：主行品牌 tint 略高，下方洞察行略低一档。
enum OverviewSurfaceTone { primary, insight }

/// 主题色推导的概览视觉面：连续曲率圆角，不引入固定卡片色。
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
    final highlight = context.appColors.overviewSurfaceHighlight;

    return Container(
      width: double.infinity,
      constraints: minHeight == null
          ? null
          : BoxConstraints(minHeight: minHeight!),
      child: DecoratedBox(
        decoration: ShapeDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: style.gradient,
          ),
          shape: RoundedSuperellipseBorder(
            borderRadius: radius,
            side: BorderSide(color: style.borderColor),
          ),
        ),
        child: ClipRSuperellipse(
          borderRadius: radius,
          child: Stack(
            children: <Widget>[
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
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                height: spacing.xxl * 2,
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: <Color>[
                          highlight,
                          highlight.withValues(alpha: 0),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: padding ?? EdgeInsets.all(spacing.xl),
                child: child,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
