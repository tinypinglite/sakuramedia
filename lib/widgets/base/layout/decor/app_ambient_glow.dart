import 'package:material_ui/material_ui.dart';

/// 环境背景中的柔和径向光斑。
///
/// 桌面与移动壳层共享同一套光斑绘制，只由调用方决定尺寸、位置和颜色。
class AppAmbientGlow extends StatelessWidget {
  const AppAmbientGlow({super.key, required this.size, required this.color});

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
