import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/core/platform/haptic_feedback.dart';

/// 卡片右键 / 长按上下文菜单的统一触发层。
///
/// 包住卡片：桌面右键、触摸端长按都经 [onRequestMenu] 给出全局坐标（直接喂给
/// `showAppActionMenu`），长按统一补一次选择触感（桌面端无副作用）。
/// 与 `AppInteractiveSurface.onLongPress` 不要叠在同一命中区，避免重复触感。
class AppContextMenuTrigger extends StatelessWidget {
  const AppContextMenuTrigger({
    super.key,
    required this.onRequestMenu,
    required this.child,
  });

  /// 菜单弹出位置（全局坐标）。
  final ValueChanged<Offset> onRequestMenu;

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.deferToChild,
      onSecondaryTapDown: (details) => onRequestMenu(details.globalPosition),
      onLongPressStart: (details) {
        triggerSelectionHaptic();
        onRequestMenu(details.globalPosition);
      },
      child: child,
    );
  }
}
