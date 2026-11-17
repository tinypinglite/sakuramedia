import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/app/providers/app_shell_providers.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/actions/app_icon_button.dart';

/// AppIconButton(compact) 按钮边长：iconSizeMd(20) + xs(4) × 2。
const double sidebarToggleButtonSize = appCompactIconButtonSize;

/// 收起/展开按钮在窗口坐标系里的固定水平位置：macOS 排在红绿灯区
///（[desktopMacTrafficLightInsetWidth] + [desktopTitleBarControlGap]），
/// 其它平台贴窗口左缘 [AppSpacing.sm]。
double sidebarToggleButtonLeft(BuildContext context) {
  if (defaultTargetPlatform == TargetPlatform.macOS) {
    final tokens = context.appComponentTokens;
    return tokens.desktopMacTrafficLightInsetWidth +
        tokens.desktopTitleBarControlGap;
  }
  return context.appSpacing.sm;
}

/// 桌面壳侧边栏收起/展开按钮。
///
/// 由桌面壳层渲染在窗口坐标系固定位置（红绿灯右侧），不随侧栏/顶栏
/// 布局切换移动；收起态侧栏完全隐藏，按钮留在原地。
class AppSidebarToggleButton extends ConsumerWidget {
  const AppSidebarToggleButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AppIconButton(
      key: const Key('sidebar-toggle-button'),
      iconColor: context.appTextPalette.primary,
      onPressed: ref.read(appShellSidebarCollapsedProvider.notifier).toggle,
      icon: const Icon(Icons.vertical_split_rounded),
    );
  }
}
