import 'package:flutter/widgets.dart';
import 'package:sakuramedia/widgets/base/layout/glass/app_glass_backend.dart';
import 'package:sakuramedia/widgets/base/layout/glass/app_glass_runtime.dart';
import 'package:sakuramedia/widgets/base/layout/glass/app_glass_surface.dart';

class AppSurface extends StatelessWidget {
  const AppSurface({
    super.key,
    required this.child,
    this.borderRadius,
    this.padding,
    this.width,
    this.height,
  });

  final Widget child;
  final BorderRadius? borderRadius;
  final EdgeInsetsGeometry? padding;
  final double? width;
  final double? height;

  @override
  Widget build(BuildContext context) {
    return AppGlassSurface(
      borderRadius: borderRadius,
      padding: padding,
      width: width,
      height: height,
      child: child,
    );
  }
}

class AppSurfaceGroup extends StatelessWidget {
  const AppSurfaceGroup({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AppGlassBackdropGroupBackend(child: child);
  }
}

abstract final class AppSurfaceRuntime {
  static Future<void> initialize() => AppGlassRuntime.initialize();

  static Widget wrap({
    required Widget child,
    Brightness? Function(BuildContext)? brightnessResolver,
  }) {
    return AppGlassRuntime.wrap(
      child: child,
      brightnessResolver: brightnessResolver,
    );
  }
}
