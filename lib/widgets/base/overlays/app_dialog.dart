import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/theme.dart';

/// 桌面弹窗统一入口。
///
/// 使用与 `liquid_glass_widgets` 的 `GlassDialog` 相同的整树淡出：关闭时
/// 内容和玻璃一起退场，不使用 materialize 的内容/玻璃错峰动画，避免大弹窗
/// 关闭时先抽掉内容、只留下玻璃骨架。
Future<T?> showAppDialog<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool barrierDismissible = true,
  Color? barrierColor,
  bool useRootNavigator = true,
}) {
  final dialogTheme = DialogTheme.of(context);
  final resolvedBarrierColor =
      barrierColor ??
      dialogTheme.barrierColor ??
      context.appColors.modalBarrier;

  return showDialog<T>(
    context: context,
    builder: builder,
    barrierColor: resolvedBarrierColor,
    barrierDismissible: barrierDismissible,
    useRootNavigator: useRootNavigator,
    traversalEdgeBehavior: TraversalEdgeBehavior.closedLoop,
    animationStyle: const AnimationStyle(
      duration: Duration(milliseconds: 250),
      curve: Curves.easeOut,
      reverseCurve: Curves.easeOut,
    ),
  );
}
