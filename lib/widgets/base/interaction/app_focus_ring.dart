import 'package:material_ui/material_ui.dart';

/// 键盘焦点环：用前景装饰绘制，不改变子节点布局。
class AppFocusRing extends StatelessWidget {
  const AppFocusRing({
    super.key,
    required this.focused,
    required this.child,
    this.borderRadius,
    this.color,
    this.width = 2,
  });

  final bool focused;
  final Widget child;
  final BorderRadius? borderRadius;
  final Color? color;
  final double width;

  @override
  Widget build(BuildContext context) {
    if (!focused) {
      return child;
    }
    return DecoratedBox(
      position: DecorationPosition.foreground,
      decoration: BoxDecoration(
        borderRadius: borderRadius ?? BorderRadius.zero,
        border: Border.all(
          color: color ?? Theme.of(context).colorScheme.primary,
          width: width,
        ),
      ),
      child: child,
    );
  }
}
