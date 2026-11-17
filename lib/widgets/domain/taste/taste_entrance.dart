import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/theme.dart';

/// 口味区块首次出现时的淡入上移动效；减少动态效果时原样渲染。
class TasteEntrance extends StatelessWidget {
  const TasteEntrance({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context)) {
      return child;
    }
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: 1),
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, context.appSpacing.sm * (1 - value)),
            child: child,
          ),
        );
      },
      child: child,
    );
  }
}
