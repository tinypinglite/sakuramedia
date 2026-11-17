import 'package:material_ui/material_ui.dart';

/// 页级竖向滚动容器：**顶部禁止下拉过卷**，底部保留平台默认过卷手感。
///
/// - 顶部（leading edge）继续下拉：边界直接夹住，内容零位移、零回弹；同时压掉
///   Android 的拉伸 / 光晕指示，视觉上完全不可下拉。
/// - 底部（trailing edge）上滑到底：边界判断交回平台默认物理，iOS / macOS 的
///   橡皮筋回弹与 Android 的拉伸照旧。
/// - 只处理自身这条竖向滚动：内部横向列表的过卷通知 `depth != 0`，横向手感保持
///   不变。
///
/// 用法与 [CustomScrollView] 一致（只交出 slivers），因此不接受 `physics`——
/// 顶部钉住是本组件的既定语义。
class AppNoPullDownScrollView extends StatelessWidget {
  const AppNoPullDownScrollView({
    super.key,
    required this.slivers,
    this.controller,
  });

  final List<Widget> slivers;
  final ScrollController? controller;

  @override
  Widget build(BuildContext context) {
    return NotificationListener<OverscrollIndicatorNotification>(
      onNotification: (notification) {
        // depth == 0 才是这条页面滚动的过卷；嵌套横向列表（depth != 0）不碰。
        if (notification.depth == 0 && notification.leading) {
          notification.disallowIndicator();
        }
        return false;
      },
      child: CustomScrollView(
        controller: controller,
        physics: const _NoPullDownScrollPhysics(),
        slivers: slivers,
      ),
    );
  }
}

/// 顶部夹紧、其余沿用平台默认物理的滚动物理。
///
/// 只覆写 [applyBoundaryConditions]：顶部的两条判断与 [ClampingScrollPhysics]
/// 完全一致；底部把判断交回 `parent`（框架会自动挂上平台默认物理），因此
/// iOS / macOS 的回弹与 Android 的拉伸都不变。弹道模拟、尺寸变化校正、过卷
/// 摩擦等其余行为本就由 [ScrollPhysics] 委托给父物理。
class _NoPullDownScrollPhysics extends ScrollPhysics {
  const _NoPullDownScrollPhysics({super.parent});

  @override
  _NoPullDownScrollPhysics applyTo(ScrollPhysics? ancestor) =>
      _NoPullDownScrollPhysics(parent: buildParent(ancestor));

  @override
  double applyBoundaryConditions(ScrollMetrics position, double value) {
    if (value < position.pixels &&
        position.pixels <= position.minScrollExtent) {
      // 已在顶部还继续下拉：夹住，零位移。
      return value - position.pixels;
    }
    if (value < position.minScrollExtent &&
        position.minScrollExtent < position.pixels) {
      // 往回滚到顶部：最多停在顶部边界。
      return value - position.minScrollExtent;
    }
    return parent?.applyBoundaryConditions(position, value) ?? 0.0;
  }
}
