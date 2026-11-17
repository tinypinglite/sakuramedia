import 'dart:ui' show lerpDouble;

import 'package:material_ui/material_ui.dart';

@immutable
class AppShadows extends ThemeExtension<AppShadows> {
  const AppShadows({
    required this.color,
    required this.panelBlur,
    required this.offsetY,
    required this.indicatorColor,
    required this.indicatorBlur,
    required this.indicatorOffsetY,
  });

  const AppShadows.defaults()
    : color = const Color(0x142B1816),
      panelBlur = 24,
      offsetY = 8,
      indicatorColor = const Color.fromRGBO(0, 0, 0, 0.08),
      indicatorBlur = 7,
      indicatorOffsetY = 2;

  const AppShadows.dark()
    : color = const Color(0x40000000),
      panelBlur = 24,
      offsetY = 8,
      indicatorColor = const Color.fromRGBO(0, 0, 0, 0.24),
      indicatorBlur = 7,
      indicatorOffsetY = 2;

  final Color color;
  final double panelBlur;
  final double offsetY;
  final Color indicatorColor;
  final double indicatorBlur;
  final double indicatorOffsetY;

  /// 浮层阴影：只用于菜单、弹窗、侧栏等临时浮层。
  ///
  /// 静态卡片不再使用投影，靠 `surfaceCard` 底色 + 1px `borderSubtle`
  /// 边框和圆角分层。
  List<BoxShadow> get panel => [
    BoxShadow(color: color, blurRadius: panelBlur, offset: Offset(0, offsetY)),
  ];

  /// 分段控件选中胶囊的轻量投影。
  List<BoxShadow> get indicator => [
    BoxShadow(
      color: indicatorColor,
      blurRadius: indicatorBlur,
      offset: Offset(0, indicatorOffsetY),
    ),
  ];

  @override
  AppShadows copyWith({
    Color? color,
    double? panelBlur,
    double? offsetY,
    Color? indicatorColor,
    double? indicatorBlur,
    double? indicatorOffsetY,
  }) {
    return AppShadows(
      color: color ?? this.color,
      panelBlur: panelBlur ?? this.panelBlur,
      offsetY: offsetY ?? this.offsetY,
      indicatorColor: indicatorColor ?? this.indicatorColor,
      indicatorBlur: indicatorBlur ?? this.indicatorBlur,
      indicatorOffsetY: indicatorOffsetY ?? this.indicatorOffsetY,
    );
  }

  @override
  AppShadows lerp(ThemeExtension<AppShadows>? other, double t) {
    if (other is! AppShadows) {
      return this;
    }
    return AppShadows(
      color: Color.lerp(color, other.color, t)!,
      panelBlur: lerpDouble(panelBlur, other.panelBlur, t)!,
      offsetY: lerpDouble(offsetY, other.offsetY, t)!,
      indicatorColor: Color.lerp(indicatorColor, other.indicatorColor, t)!,
      indicatorBlur: lerpDouble(indicatorBlur, other.indicatorBlur, t)!,
      indicatorOffsetY: lerpDouble(
        indicatorOffsetY,
        other.indicatorOffsetY,
        t,
      )!,
    );
  }
}

extension AppShadowsThemeDataX on ThemeData {
  AppShadows get appShadows =>
      extension<AppShadows>() ?? const AppShadows.defaults();
}

extension AppShadowsBuildContextX on BuildContext {
  AppShadows get appShadows => Theme.of(this).appShadows;
}
