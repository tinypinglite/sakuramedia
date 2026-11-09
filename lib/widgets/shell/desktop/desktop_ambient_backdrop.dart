import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/layout/decor/app_ambient_glow.dart';

/// macOS / Windows 桌面壳层的环境光背景。
///
/// macOS 开启窗口毛玻璃时，原生 `NSVisualEffectView` 负责窗口背后的真实模糊；
/// 这里只叠加一层低透明度的主题色 veil 和对角线光感，让右侧内容区不再被纯白
/// 盖死。关闭窗口毛玻璃后，这层 veil 落在不透明窗口底色上，不再有背景模糊。
/// 不额外使用 [BackdropFilter]，避免在原生 vibrancy 之上再付一层模糊成本。
class DesktopAmbientBackdrop extends StatelessWidget {
  const DesktopAmbientBackdrop({super.key, this.enabled = true});

  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final colors = context.appColors;
    final highContrast = MediaQuery.maybeHighContrastOf(context) ?? false;
    if (!enabled || highContrast) {
      return ColoredBox(
        key: const Key('desktop-ambient-backdrop'),
        color: colors.surfacePage,
      );
    }

    final scheme = Theme.of(context).colorScheme;
    final light = Color.lerp(
      scheme.primary,
      colors.highlight,
      dark ? 0.28 : 0.52,
    )!;
    final warm = Color.lerp(
      scheme.secondary,
      colors.highlight,
      dark ? 0.24 : 0.46,
    )!;

    return Stack(
      key: const Key('desktop-ambient-backdrop'),
      fit: StackFit.expand,
      children: <Widget>[
        ColoredBox(
          color: dark
              ? colors.surfacePage.withValues(alpha: 0.90)
              : colors.highlight.withValues(alpha: 0.20),
        ),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: <Color>[
                light.withValues(alpha: dark ? 0.17 : 0.16),
                light.withValues(alpha: 0.035),
                warm.withValues(alpha: dark ? 0.10 : 0.075),
              ],
              stops: const <double>[0, 0.48, 1],
            ),
          ),
        ),
        Positioned(
          left: -180,
          top: -220,
          child: AppAmbientGlow(
            size: 560,
            color: light.withValues(alpha: dark ? 0.26 : 0.23),
          ),
        ),
        Positioned(
          right: -220,
          bottom: -260,
          child: AppAmbientGlow(
            size: 600,
            color: warm.withValues(alpha: dark ? 0.17 : 0.13),
          ),
        ),
      ],
    );
  }
}
