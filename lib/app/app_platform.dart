import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

enum AppPlatform { desktop, mobile }

/// 把全程不变的 [AppPlatform] 挂进 widget 树的 InheritedWidget。
///
/// 平台是启动即定的常量，不需要状态框架承载——base 层组件
/// （app_tab_bar / app_confirm_dialog / app_adaptive_modal 等，含无法改成
/// ConsumerWidget 的顶层函数）用 [AppPlatformScope.maybeOf] 软查找，
/// 查不到（测试没包 scope）时各自回退桌面形态，与旧
/// `Provider.of<AppPlatform?>` 的语义一致。
class AppPlatformScope extends InheritedWidget {
  const AppPlatformScope({
    super.key,
    required this.platform,
    required super.child,
  });

  final AppPlatform platform;

  static AppPlatform? maybeOf(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<AppPlatformScope>()
        ?.platform;
  }

  @override
  bool updateShouldNotify(AppPlatformScope oldWidget) {
    return platform != oldWidget.platform;
  }
}

enum AppShellLayout { standard, fullscreen }

AppPlatform resolveAppPlatform({AppPlatform? override}) {
  if (override != null) {
    return override;
  }
  switch (defaultTargetPlatform) {
    case TargetPlatform.macOS:
    case TargetPlatform.windows:
      return AppPlatform.desktop;
    case TargetPlatform.iOS:
    case TargetPlatform.android:
      return AppPlatform.mobile;
    default:
      throw UnsupportedError(
        'SakuraMedia does not support ${defaultTargetPlatform.name}.',
      );
  }
}

bool isMobileAppPlatform({AppPlatform? override}) {
  return resolveAppPlatform(override: override) == AppPlatform.mobile;
}
