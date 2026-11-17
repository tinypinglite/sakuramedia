import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/widgets/base/navigation/app_back_guard.dart';

typedef AppMobileSubpageBackHandler = Future<bool> Function();

/// 页面注册到子页壳的返回拦截器。默认没有处理函数时直接放行。
class AppMobileSubpageBackInterceptorController {
  AppMobileSubpageBackInterceptorController({AppBackGuardController? guard})
    : _guard = guard;

  final AppBackGuardController? _guard;
  final ValueNotifier<bool> _canPop = ValueNotifier<bool>(true);
  AppMobileSubpageBackHandler? _handler;
  AppBackGuardRegistration? _guardRegistration;

  /// 页面同步声明的路由返回资格。
  ///
  /// `false` 会让 [PopScope] 保留拦截能力并关闭 iOS 侧滑等平台返回手势；
  /// 没有页面注册 handler 时始终为 `true`。
  ValueListenable<bool> get canPop => _canPop;

  void attach(AppMobileSubpageBackHandler handler) {
    _handler = handler;
    _guardRegistration?.dispose();
    _guardRegistration = _guard?.register(handler);
    _setCanPop(true);
  }

  void detach(AppMobileSubpageBackHandler handler) {
    if (_handler != handler) return;
    _handler = null;
    _guardRegistration?.dispose();
    _guardRegistration = null;
    _setCanPop(true);
  }

  /// 由页面在脏状态变化时同步调用。
  void setCanPop(bool canPop) {
    _setCanPop(_handler == null || canPop);
  }

  Future<bool> shouldPop() async {
    final handler = _handler;
    return handler == null || await handler();
  }

  void _setCanPop(bool canPop) {
    if (_canPop.value == canPop) return;
    _canPop.value = canPop;
  }

  void dispose() {
    _handler = null;
    _guardRegistration?.dispose();
    _guardRegistration = null;
    _canPop.dispose();
  }
}

class AppMobileSubpageBackInterceptor extends InheritedWidget {
  const AppMobileSubpageBackInterceptor({
    super.key,
    required this.controller,
    required super.child,
  });

  final AppMobileSubpageBackInterceptorController controller;

  static AppMobileSubpageBackInterceptorController? maybeOf(
    BuildContext context,
  ) {
    return context
        .dependOnInheritedWidgetOfExactType<AppMobileSubpageBackInterceptor>()
        ?.controller;
  }

  @override
  bool updateShouldNotify(AppMobileSubpageBackInterceptor oldWidget) =>
      controller != oldWidget.controller;
}
