import 'package:flutter/widgets.dart';
import 'package:flutter_hooks/flutter_hooks.dart';

/// 页面级 hook：把「滚到底触发下一页」的样板收敛到一处。
///
/// - [onReachBottom]：接近底部时调用。每次 rebuild 会更新到最新闭包，`useEffect`
///   不会因为闭包 identity 变化而反复重绑。
/// - [external]：若页面已有 ScrollController（例如 `AppPageFrame` 传入的），传它复用；
///   否则内部创建一个（`useScrollController`）并在 dispose 时销毁。
/// - [triggerOffset]：距 `maxScrollExtent` 多少像素时开始触发（默认 400，与
///   `PagedLoadController` 常用值一致）。
/// - [enabled]：false 时不绑 listener（例如 tab 页非活跃时避免误触发 loadMore）。
/// - [keys]：额外依赖列表——变化会重新绑定 listener（例如切 tab 后想切换目标）。
ScrollController usePagedLoadMoreScroll({
  required VoidCallback onReachBottom,
  ScrollController? external,
  double triggerOffset = 400,
  bool enabled = true,
  List<Object?> keys = const <Object?>[],
}) {
  final internal = useScrollController();
  final controller = external ?? internal;

  final callback = useRef<VoidCallback>(onReachBottom);
  callback.value = onReachBottom;

  useEffect(() {
    if (!enabled) {
      return null;
    }
    void listener() {
      if (!controller.hasClients) return;
      final position = controller.position;
      if (position.pixels >= position.maxScrollExtent - triggerOffset) {
        callback.value();
      }
    }

    controller.addListener(listener);
    return () => controller.removeListener(listener);
  }, <Object?>[controller, triggerOffset, enabled, ...keys]);

  return controller;
}
