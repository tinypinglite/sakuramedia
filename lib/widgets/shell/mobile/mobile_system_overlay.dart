import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:sakuramedia/theme.dart';

/// 移动壳层的系统栏样式：状态栏和导航栏跟随应用卡片底色与明暗模式。
SystemUiOverlayStyle resolveMobileSystemOverlayStyle(BuildContext context) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  return SystemUiOverlayStyle(
    statusBarColor: context.appColors.surfaceCard,
    statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
    statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
    systemNavigationBarColor: context.appColors.surfaceCard,
    systemNavigationBarIconBrightness: isDark
        ? Brightness.light
        : Brightness.dark,
    systemNavigationBarDividerColor: context.appColors.divider,
  );
}
