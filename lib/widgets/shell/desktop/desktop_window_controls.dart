import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/shell/desktop/app_sidebar_toggle_button.dart';
import 'package:sakuramedia/widgets/shell/desktop/desktop_chrome_policy.dart';
import 'package:sakuramedia/widgets/shell/window/app_mac_traffic_lights.dart';

/// 桌面窗口左上角的自绘控制区。
///
/// 只负责窗口级控制，不参与页面布局；位置固定在窗口坐标系，不随侧栏宽度动画。
class DesktopWindowControls extends StatelessWidget {
  const DesktopWindowControls({super.key, required this.policy});

  final DesktopChromePolicy policy;

  @override
  Widget build(BuildContext context) {
    final titleBarHeight = context.appComponentTokens.desktopTitleBarHeight;
    return Stack(
      children: [
        if (policy.usesMacTrafficLights)
          Positioned(
            left: appMacTrafficLightsLeft,
            top: (titleBarHeight - appMacTrafficLightButtonSize) / 2,
            child: const AppMacTrafficLights(),
          ),
        Positioned(
          left: policy.sidebarToggleLeft,
          top: (titleBarHeight - sidebarToggleButtonSize) / 2,
          child: const AppSidebarToggleButton(),
        ),
      ],
    );
  }
}
