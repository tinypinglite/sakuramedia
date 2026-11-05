import 'dart:ui' show lerpDouble;

import 'package:material_ui/material_ui.dart';

@immutable
class AppSidebarTokens extends ThemeExtension<AppSidebarTokens> {
  const AppSidebarTokens({
    required this.expandedWidth,
    required this.collapsedWidth,
    required this.itemHeight,
    required this.outerInset,
    required this.panelRadius,
  });

  const AppSidebarTokens.defaults()
    : expandedWidth = 220,
      // 收起 = 完全隐藏，内容区占满窗口宽度。
      collapsedWidth = 0,
      itemHeight = 44,
      outerInset = 8,
      panelRadius = 24;

  final double expandedWidth;
  final double collapsedWidth;
  final double itemHeight;

  /// 玻璃面板与窗口边缘之间的留白。
  final double outerInset;

  /// 玻璃面板圆角。
  final double panelRadius;

  /// 展开态在壳层 row 中占据的总宽度：玻璃面板 + 两侧内收边距。
  double get expandedFootprintWidth => expandedWidth + outerInset * 2;

  @override
  AppSidebarTokens copyWith({
    double? expandedWidth,
    double? collapsedWidth,
    double? itemHeight,
    double? outerInset,
    double? panelRadius,
  }) {
    return AppSidebarTokens(
      expandedWidth: expandedWidth ?? this.expandedWidth,
      collapsedWidth: collapsedWidth ?? this.collapsedWidth,
      itemHeight: itemHeight ?? this.itemHeight,
      outerInset: outerInset ?? this.outerInset,
      panelRadius: panelRadius ?? this.panelRadius,
    );
  }

  @override
  AppSidebarTokens lerp(ThemeExtension<AppSidebarTokens>? other, double t) {
    if (other is! AppSidebarTokens) {
      return this;
    }
    return AppSidebarTokens(
      expandedWidth: lerpDouble(expandedWidth, other.expandedWidth, t)!,
      collapsedWidth: lerpDouble(collapsedWidth, other.collapsedWidth, t)!,
      itemHeight: lerpDouble(itemHeight, other.itemHeight, t)!,
      outerInset: lerpDouble(outerInset, other.outerInset, t)!,
      panelRadius: lerpDouble(panelRadius, other.panelRadius, t)!,
    );
  }
}

extension AppSidebarTokensThemeDataX on ThemeData {
  AppSidebarTokens get appSidebarTokens =>
      extension<AppSidebarTokens>() ?? const AppSidebarTokens.defaults();
}

extension AppSidebarTokensBuildContextX on BuildContext {
  AppSidebarTokens get appSidebarTokens => Theme.of(this).appSidebarTokens;
}
