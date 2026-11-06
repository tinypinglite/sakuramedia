import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/widgets/base/interaction/app_interactive_surface.dart';

/// 为没有内置鼠标指针的项目自定义点击区域提供统一的鼠标指针。
///
/// 这个组件只负责指针，不负责点击回调，适合包在自定义
/// [GestureDetector] 外面。若交互组件本身是 [InkWell]，应直接设置它的
/// `mouseCursor`；内层 [InkWell] 的鼠标区域会覆盖外层的指针。禁用时保留
/// 系统默认箭头指针。
///
/// 需要点击/长按/右键语义时直接传对应回调；此时内部改走
/// [AppInteractiveSurface]，同时获得键盘激活与焦点环。
class AppClickable extends StatelessWidget {
  const AppClickable({
    super.key,
    required this.enabled,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.onSecondaryTap,
    this.semanticLabel,
    this.focusRing = true,
  });

  final bool enabled;
  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final VoidCallback? onSecondaryTap;
  final String? semanticLabel;
  final bool focusRing;

  bool get _usesInteractiveSurface =>
      onTap != null || onLongPress != null || onSecondaryTap != null;

  @override
  Widget build(BuildContext context) {
    if (_usesInteractiveSurface) {
      return AppInteractiveSurface(
        enabled: enabled,
        onTap: onTap,
        onLongPress: onLongPress,
        onSecondaryTap: onSecondaryTap,
        semanticLabel: semanticLabel,
        focusRing: focusRing,
        child: child,
      );
    }
    return MouseRegion(
      cursor: enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
      child: child,
    );
  }
}
