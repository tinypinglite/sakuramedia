import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/layout/decor/app_ambient_glow.dart';

/// 桌面 / 移动壳层共用的主题色环境光背景。
class AppAmbientBackdrop extends StatelessWidget {
  const AppAmbientBackdrop({
    super.key,
    this.mobile = false,
    this.enabled = true,
    this.child,
  });

  final bool mobile;
  final bool enabled;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final colors = context.appColors;
    final highContrast = MediaQuery.maybeHighContrastOf(context) ?? false;
    final backdropKey = Key(
      mobile ? 'mobile-ambient-backdrop' : 'desktop-ambient-backdrop',
    );
    if ((!mobile && !enabled) || highContrast) {
      return ColoredBox(
        key: backdropKey,
        color: colors.surfacePage,
        child: child,
      );
    }

    final scheme = Theme.of(context).colorScheme;
    final light = Color.lerp(
      scheme.primary,
      colors.highlight,
      mobile ? (dark ? 0.3 : 0.62) : (dark ? 0.28 : 0.52),
    )!;
    final warm = Color.lerp(
      scheme.secondary,
      colors.highlight,
      mobile ? (dark ? 0.24 : 0.52) : (dark ? 0.24 : 0.46),
    )!;

    return Stack(
      key: backdropKey,
      fit: StackFit.expand,
      children: <Widget>[
        ColoredBox(
          color: mobile
              ? (dark
                    ? colors.surfacePage.withValues(alpha: 0.94)
                    : colors.surfacePage)
              : (dark
                    ? colors.surfacePage.withValues(alpha: 0.90)
                    : colors.highlight.withValues(alpha: 0.20)),
        ),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: mobile
                  ? <Color>[
                      light.withValues(alpha: dark ? 0.2 : 0.25),
                      light.withValues(alpha: 0.025),
                      warm.withValues(alpha: dark ? 0.1 : 0.12),
                    ]
                  : <Color>[
                      light.withValues(alpha: dark ? 0.17 : 0.16),
                      light.withValues(alpha: 0.035),
                      warm.withValues(alpha: dark ? 0.10 : 0.075),
                    ],
              stops: mobile
                  ? const <double>[0, 0.42, 1]
                  : const <double>[0, 0.48, 1],
            ),
          ),
        ),
        Positioned(
          left: mobile ? -160 : -180,
          top: mobile ? -180 : -220,
          child: AppAmbientGlow(
            size: mobile ? 460 : 560,
            color: light.withValues(
              alpha: mobile ? (dark ? 0.25 : 0.3) : (dark ? 0.26 : 0.23),
            ),
          ),
        ),
        Positioned(
          right: mobile ? -180 : -220,
          bottom: mobile ? -220 : -260,
          child: AppAmbientGlow(
            size: mobile ? 520 : 600,
            color: warm.withValues(
              alpha: mobile ? (dark ? 0.16 : 0.18) : (dark ? 0.17 : 0.13),
            ),
          ),
        ),
        ?child,
      ],
    );
  }
}
