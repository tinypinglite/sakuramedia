import 'package:material_ui/material_ui.dart';

/// 导航变化时关闭已经打开的 Tooltip。
///
/// Flutter 3.47 的 Tooltip overlay 在被不透明路由遮住后仍会留在
/// Overlay theater 中；此时窗口尺寸变化可能触发 OverlayPortal 的尺寸断言。
/// 路由切换时先让现有 Tooltip 收起，避免它们跨路由继续持有 overlay child。
class AppTooltipNavigatorObserver extends NavigatorObserver {
  AppTooltipNavigatorObserver();

  void _dismissTooltips() {
    Tooltip.dismissAllToolTips();
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _dismissTooltips();
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _dismissTooltips();
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    _dismissTooltips();
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _dismissTooltips();
  }
}
