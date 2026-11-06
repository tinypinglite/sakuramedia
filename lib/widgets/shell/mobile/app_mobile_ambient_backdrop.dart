import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/layout/decor/app_ambient_glow.dart';

/// 移动端玻璃页的环境光背景。
///
/// 和桌面 `DesktopAmbientBackdrop` 共用同一套主题色光感，但光斑更大、更柔，
/// 避免手机窄屏上出现明显的色带。高对比度模式直接回退为纯页面底色。
class AppMobileAmbientBackdrop extends StatelessWidget {
  const AppMobileAmbientBackdrop({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final highContrast = MediaQuery.maybeHighContrastOf(context) ?? false;
    final colors = context.appColors;
    if (highContrast) {
      return ColoredBox(
        key: const Key('mobile-ambient-backdrop'),
        color: colors.surfacePage,
        child: child,
      );
    }

    final scheme = Theme.of(context).colorScheme;
    final light = Color.lerp(
      scheme.primary,
      colors.highlight,
      dark ? 0.3 : 0.62,
    )!;
    final warm = Color.lerp(
      scheme.secondary,
      colors.highlight,
      dark ? 0.24 : 0.52,
    )!;

    return Stack(
      key: const Key('mobile-ambient-backdrop'),
      fit: StackFit.expand,
      children: <Widget>[
        ColoredBox(
          color: dark
              ? colors.surfacePage.withValues(alpha: 0.94)
              : colors.surfacePage,
        ),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: <Color>[
                light.withValues(alpha: dark ? 0.2 : 0.25),
                light.withValues(alpha: 0.025),
                warm.withValues(alpha: dark ? 0.1 : 0.12),
              ],
              stops: const <double>[0, 0.42, 1],
            ),
          ),
        ),
        Positioned(
          left: -160,
          top: -180,
          child: AppAmbientGlow(
            size: 460,
            color: light.withValues(alpha: dark ? 0.25 : 0.3),
          ),
        ),
        Positioned(
          right: -180,
          bottom: -220,
          child: AppAmbientGlow(
            size: 520,
            color: warm.withValues(alpha: dark ? 0.16 : 0.18),
          ),
        ),
        child,
      ],
    );
  }
}
