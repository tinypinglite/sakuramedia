import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import 'package:sakuramedia/widgets/base/interaction/refresh/app_page_refresh_scope.dart';

/// 页面刷新回调的单一来源。
///
/// 页面通过 [AppPageRefreshScope] 注册/注销回调；壳层只监听 [listenable]，
/// 不再需要在 build 阶段手动判断 scheduler 状态。
class AppPageRefreshController {
  final List<AppPageRefreshCallback> _stack = <AppPageRefreshCallback>[];
  final ValueNotifier<AppPageRefreshCallback?> _current =
      ValueNotifier<AppPageRefreshCallback?>(null);

  late final AppPageRefreshRegistrar registrar = AppPageRefreshRegistrar(
    register: _register,
    unregister: _unregister,
  );

  AppPageRefreshCallback? get current => _current.value;

  ValueListenable<AppPageRefreshCallback?> get listenable => _current;
  bool _disposed = false;

  void _register(AppPageRefreshCallback callback) {
    _stack
      ..remove(callback)
      ..add(callback);
    _sync();
  }

  void _unregister(AppPageRefreshCallback callback) {
    if (_stack.remove(callback)) {
      _sync();
    }
  }

  void _sync() {
    final next = _stack.isEmpty ? null : _stack.last;
    if (identical(_current.value, next)) {
      return;
    }
    final binding = WidgetsBinding.instance;
    final building = binding.buildOwner?.debugBuilding ?? false;
    final phase = SchedulerBinding.instance.schedulerPhase;
    if (!building &&
        (phase == SchedulerPhase.idle ||
            phase == SchedulerPhase.postFrameCallbacks)) {
      _current.value = next;
      return;
    }
    binding.addPostFrameCallback((_) {
      if (!_disposed && !identical(_current.value, next)) {
        _current.value = next;
      }
    });
  }

  void dispose() {
    _disposed = true;
    _stack.clear();
    _current.dispose();
  }
}
