import 'package:flutter/gestures.dart';
import 'package:material_ui/material_ui.dart';

/// 包裹「内部含 [SelectableText] 的滚动区域」，把鼠标从可拖拽滚动的指针集合里排除。
///
/// 鼠标拖拽滚动会和文本选择抢手势：滚动容器的拖拽阈值是鼠标 1px
/// (`kPrecisePointerHitSlop`)，文本选择是 2px (`kPrecisePointerPanSlop`)，
/// 真实鼠标每个 move 事件通常只移动 1~2px，于是滚动先接受手势并取消选择
/// （表现为「鼠标怎么拖都选不中文字」）。触摸、触控板与注入手势 (`unknown`)
/// 仍可拖拽滚动，鼠标滚轮和滚动条不受影响。
class AppSelectableTextScrollConfiguration extends StatelessWidget {
  const AppSelectableTextScrollConfiguration({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final configuration = ScrollConfiguration.of(context);
    return ScrollConfiguration(
      behavior: configuration.copyWith(
        dragDevices: configuration.dragDevices.difference(
          const <PointerDeviceKind>{PointerDeviceKind.mouse},
        ),
      ),
      child: child,
    );
  }
}
