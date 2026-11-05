import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/theme.dart';

/// macOS / Windows 桌面壳层的环境光背景。
///
/// macOS 的原生 `NSVisualEffectView` 已负责窗口背后的真实模糊；这里只叠加
/// 一层低透明度的主题色 veil 和对角线光感，让右侧内容区不再被纯白盖死。
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
    final light = Color.lerp(scheme.primary, Colors.white, dark ? 0.28 : 0.52)!;
    final warm = Color.lerp(
      scheme.secondary,
      Colors.white,
      dark ? 0.24 : 0.46,
    )!;

    return Stack(
      key: const Key('desktop-ambient-backdrop'),
      fit: StackFit.expand,
      children: <Widget>[
        ColoredBox(
          color: dark
              ? const Color(0x420C090B)
              : Colors.white.withValues(alpha: 0.20),
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
          child: _AmbientGlow(
            size: 560,
            color: light.withValues(alpha: dark ? 0.26 : 0.23),
          ),
        ),
        Positioned(
          right: -220,
          bottom: -260,
          child: _AmbientGlow(
            size: 600,
            color: warm.withValues(alpha: dark ? 0.17 : 0.13),
          ),
        ),
      ],
    );
  }
}

class _AmbientGlow extends StatelessWidget {
  const _AmbientGlow({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: SizedBox(
        width: size,
        height: size,
        child: DecoratedBox(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: <Color>[color, color.withValues(alpha: 0)],
            ),
          ),
        ),
      ),
    );
  }
}
