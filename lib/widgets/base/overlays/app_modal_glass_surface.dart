import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/layout/glass/app_glass_surface.dart';
import 'package:sakuramedia/widgets/base/layout/glass/app_glass_types.dart';

/// 对话框和底部抽屉共用的模态玻璃。
///
/// 和其它玻璃表面一样使用全局唯一的最低档材质，不再提供强度变体。
class AppModalGlassSurface extends StatelessWidget {
  const AppModalGlassSurface({
    super.key,
    required this.child,
    this.borderRadius,
  });

  final Widget child;
  final BorderRadius? borderRadius;

  @override
  Widget build(BuildContext context) {
    final radius = borderRadius ?? context.appRadius.xlBorder;

    return AppGlassSurface(
      borderRadius: radius,
      role: AppGlassRole.popover,
      child: child,
    );
  }
}
