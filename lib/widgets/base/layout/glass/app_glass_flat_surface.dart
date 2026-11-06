import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/layout/glass/app_glass_flat_style.dart';

/// 无模糊、无 shader 的扁平玻璃表面。
class AppGlassFlatSurface extends StatelessWidget {
  const AppGlassFlatSurface({
    super.key,
    required this.child,
    this.role = AppFlatSurfaceRole.surface,
    this.borderRadius,
    this.padding,
    this.width,
    this.height,
  });

  final Widget child;
  final AppFlatSurfaceRole role;
  final BorderRadius? borderRadius;
  final EdgeInsetsGeometry? padding;
  final double? width;
  final double? height;

  @override
  Widget build(BuildContext context) {
    final radius = borderRadius ?? context.appRadius.mdBorder;
    final recipe = AppGlassFlatStyle.recipe(context, role);

    return KeyedSubtree(
      key: const Key('app-glass-flat-surface'),
      child: Container(
        width: width,
        height: height,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(color: recipe.fill, borderRadius: radius),
        foregroundDecoration: BoxDecoration(
          borderRadius: radius,
          border: Border.all(color: recipe.border),
        ),
        child: Stack(
          children: <Widget>[
            if (!recipe.highContrast)
              Positioned(
                top: 1,
                left: 1,
                right: 1,
                height: 14,
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: <Color>[
                          recipe.highlight,
                          recipe.highlight.withValues(alpha: 0),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            Padding(padding: padding ?? EdgeInsets.zero, child: child),
          ],
        ),
      ),
    );
  }
}
