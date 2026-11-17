import 'package:material_ui/material_ui.dart';

/// 弹层入场进度。
///
/// 玻璃框架由合成器级的 backdrop pass 绘制：任何祖先 [Opacity] / [FadeTransition]
/// 都会把它包进 saveLayer，玻璃拿不到真实背景，淡入期间整块框架画不出来（要等
/// 淡入结束、图层退化成 offset 才“啪”地出现）。所以弹层转场不能淡整棵树，而是
/// 把进度传给表面自己消费：
///
/// - 液态玻璃走 [LiquidGlassSettings.visibility]（shader 的唯一合法淡入通道）；
/// - 纯绘制表面（实色弹窗等）走 [Opacity]。
///
/// 正向和反向共用同一个进度，出场不会出现“内容先消失、只剩空玻璃”的错峰。
class AppGlassEntrance extends StatelessWidget {
  const AppGlassEntrance({
    super.key,
    required this.progress,
    required this.child,
  });

  /// 0 = 完全收起，1 = 静止。
  final double progress;

  final Widget child;

  /// 最近的弹层入场进度；不在转场中时为 1。
  static double progressOf(BuildContext context) {
    return context
            .dependOnInheritedWidgetOfExactType<_AppGlassEntranceScope>()
            ?.progress ??
        1.0;
  }

  /// 暴露给表面的进度下限。
  ///
  /// 进度正好为 0 时，包内 [AdaptiveGlass] 会切换到“完全退场”的降级子树（只剩
  /// 一层 Opacity），下一帧再切回正常玻璃树会把弹窗内容重新挂载、丢掉状态。
  /// 下限取一个视觉上仍然不可见的极小值，保证整段转场里树形不变。
  static const double _minProgress = 0.001;

  @override
  Widget build(BuildContext context) {
    // 始终保留这个 InheritedWidget：动画结束时移除它会改变树形，弹窗内容会被
    // 重新挂载、丢掉状态。静止时它只是一个零成本的依赖查询。
    return _AppGlassEntranceScope(
      progress: progress.clamp(_minProgress, 1.0),
      child: child,
    );
  }
}

class _AppGlassEntranceScope extends InheritedWidget {
  const _AppGlassEntranceScope({required this.progress, required super.child});

  final double progress;

  @override
  bool updateShouldNotify(_AppGlassEntranceScope oldWidget) {
    return progress != oldWidget.progress;
  }
}
