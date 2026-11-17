import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

/// 重建挂在顶层 Overlay 上的浮层（菜单 / 弹出层），并保证调用时机合法。
///
/// 浮层和触发它的组件不在同一棵子树里。若在 build / layout 阶段直接调用
/// [OverlayEntry.markNeedsBuild]，框架会抛「setState() called during build」：
/// 该浮层元素不是当前正在构建元素的子孙，本轮构建不会访问它，只能等下一帧。
/// 常见触发点是 `didUpdateWidget` 里同步刷新浮层数据（父级重建带下来的新状态），
/// 以及 LayoutBuilder 的构建回调。
///
/// 构建期一律推迟到帧末重建——只晚一帧，肉眼无感；其余时刻立即重建，保住 hover
/// 高亮这类需要即时反馈的交互。[OverlayEntry.markNeedsBuild] 对已卸载的浮层是
/// 空操作，所以推迟期间浮层被关闭（移出 Overlay）也不会踩空。
void requestOverlayEntryRebuild(OverlayEntry? entry) {
  if (entry == null) {
    return;
  }
  final binding = WidgetsBinding.instance;
  if (!_isFrameworkBuilding(binding)) {
    entry.markNeedsBuild();
    return;
  }
  binding.addPostFrameCallback((_) {
    entry.markNeedsBuild();
  });
}

bool _isFrameworkBuilding(WidgetsBinding binding) {
  // debug 下 buildOwner 能兜住帧外的 buildScope（如 runApp 首帧）。
  if (binding.buildOwner?.debugBuilding ?? false) {
    return true;
  }
  return switch (binding.schedulerPhase) {
    SchedulerPhase.persistentCallbacks ||
    SchedulerPhase.midFrameMicrotasks => true,
    SchedulerPhase.idle ||
    SchedulerPhase.transientCallbacks ||
    SchedulerPhase.postFrameCallbacks => false,
  };
}
