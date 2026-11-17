import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/theme.dart';

/// 通用横向滚动 rail：固定高度的横向列表，卡片由调用方通过 [itemBuilder]
/// 提供（通常自行包 `SizedBox` 固定宽度）。
///
/// 触摸端横向滑动；桌面端 Shift+滚轮、触控板横滑与鼠标拖拽滚动（拖拽由全局
/// ScrollConfiguration 的 dragDevices 提供）。
class AppScrollRail extends StatelessWidget {
  const AppScrollRail({
    super.key,
    required this.height,
    required this.itemCount,
    required this.itemBuilder,
    this.scrollViewKey,
  });

  /// rail 高度；卡片高度由调用方按自身宽高比算好。
  final double height;
  final int itemCount;
  final Widget Function(BuildContext context, int index) itemBuilder;
  final Key? scrollViewKey;

  @override
  Widget build(BuildContext context) {
    final spacing = context.appSpacing.sm;
    return SizedBox(
      height: height,
      child: ListView.separated(
        key: scrollViewKey,
        scrollDirection: Axis.horizontal,
        itemCount: itemCount,
        separatorBuilder: (context, index) => SizedBox(width: spacing),
        itemBuilder: itemBuilder,
      ),
    );
  }
}
