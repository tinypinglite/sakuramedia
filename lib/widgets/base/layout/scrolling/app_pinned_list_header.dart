import 'package:material_ui/material_ui.dart';
import 'package:flutter/rendering.dart';

/// 资料区后的列表控制栏。
class AppPinnedListHeader extends StatelessWidget {
  const AppPinnedListHeader({
    super.key,
    required this.color,
    required this.child,
  });

  final Color color;
  final Widget child;

  /// 切筛选回到结果区开头；尚未滚过资料区时保留当前位置。
  static void scrollToStart(GlobalKey headerKey, ScrollController controller) {
    final renderObject = headerKey.currentContext?.findRenderObject();
    if (!controller.hasClients || renderObject == null) return;
    final viewport = RenderAbstractViewport.maybeOf(renderObject);
    if (viewport == null) return;
    final offset = viewport.getOffsetToReveal(renderObject, 0).offset;
    final position = controller.position;
    if (position.pixels > offset) {
      controller.jumpTo(
        offset.clamp(position.minScrollExtent, position.maxScrollExtent),
      );
    }
  }

  @override
  Widget build(BuildContext context) => PinnedHeaderSliver(
    child: ColoredBox(color: color, child: child),
  );
}
