import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:sakuramedia/widgets/shell/desktop/app_sidebar_toggle_button.dart';
import 'package:sakuramedia/widgets/shell/window/app_windows_caption.dart';

/// 桌面窗口 chrome 的平台策略。
///
/// shell、侧栏和顶栏共用这一份判断，避免各自复制
/// `macOS || windows` 与窗口按钮分支。
@immutable
class DesktopChromePolicy {
  const DesktopChromePolicy({
    required this.usesGlassSidebar,
    required this.usesMacTrafficLights,
    required this.usesWindowsCaption,
    required this.sidebarToggleLeft,
  });

  factory DesktopChromePolicy.of(BuildContext context) {
    final isMacOS = !kIsWeb && defaultTargetPlatform == TargetPlatform.macOS;
    final isWindows =
        !kIsWeb && defaultTargetPlatform == TargetPlatform.windows;
    return DesktopChromePolicy(
      usesGlassSidebar: isMacOS || isWindows,
      usesMacTrafficLights: isMacOS,
      usesWindowsCaption: usesAppWindowsCaption,
      sidebarToggleLeft: sidebarToggleButtonLeft(context),
    );
  }

  final bool usesGlassSidebar;
  final bool usesMacTrafficLights;
  final bool usesWindowsCaption;
  final double sidebarToggleLeft;
}
