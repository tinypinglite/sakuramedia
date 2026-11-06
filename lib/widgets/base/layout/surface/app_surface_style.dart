import 'package:flutter/widgets.dart';

/// 应用级表面风格。
enum AppSurfaceStyle {
  /// 保留折射、高光与厚度感的液态玻璃。
  liquid,

  /// 无实时模糊、无 shader 的扁平半透明表面。
  flat,
}

/// 向下传递当前表面风格；没有 scope 时按液态玻璃处理。
class AppSurfaceStyleScope extends InheritedWidget {
  const AppSurfaceStyleScope({
    super.key,
    required this.style,
    required super.child,
  });

  final AppSurfaceStyle style;

  static AppSurfaceStyle of(BuildContext context) {
    return context
            .dependOnInheritedWidgetOfExactType<AppSurfaceStyleScope>()
            ?.style ??
        AppSurfaceStyle.liquid;
  }

  @override
  bool updateShouldNotify(AppSurfaceStyleScope oldWidget) {
    return oldWidget.style != style;
  }
}
