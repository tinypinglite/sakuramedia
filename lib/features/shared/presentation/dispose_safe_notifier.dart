import 'package:flutter/foundation.dart';

/// 给「异步加载完成后 notify」的 [ChangeNotifier] 加 dispose 守卫。
///
/// 典型崩溃场景：控制器发起请求 → 用户在响应回来之前关掉页面/面板 → 宿主
/// `dispose()` 了控制器 → `await` 恢复执行后走到 `finally { notifyListeners() }`
/// → `A XxxController was used after being disposed.`
///
/// 混入后把所有**可能在 `await` 之后执行**的 `notifyListeners()` 换成
/// [notifyListenersSafely]；同步路径（setter、纯本地状态切换）用哪个都行，
/// 统一换掉更省心。
///
/// 语义与 [PagedLoadController] 内联的同名实现一致——那份因为是全项目最底层的
/// 分页基类，暂未迁过来，改动前先想清楚波及面。
mixin DisposeSafeNotifier on ChangeNotifier {
  bool _isDisposed = false;

  /// 宿主已 `dispose()`：此后任何状态写入都不该再触发 UI 刷新。
  bool get isDisposed => _isDisposed;

  /// dispose 之后静默丢弃，不抛。
  @protected
  void notifyListenersSafely() {
    if (_isDisposed) {
      return;
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _isDisposed = true;
    super.dispose();
  }
}
