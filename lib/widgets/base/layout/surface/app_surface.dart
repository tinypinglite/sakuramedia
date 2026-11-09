import 'package:flutter/widgets.dart';
import 'package:sakuramedia/widgets/base/layout/glass/app_glass_backend.dart';
import 'package:sakuramedia/widgets/base/layout/glass/app_glass_runtime.dart';
import 'package:sakuramedia/widgets/base/layout/glass/app_glass_surface.dart';
import 'package:sakuramedia/widgets/base/layout/surface/app_surface_style.dart';

export 'package:sakuramedia/widgets/base/layout/surface/app_surface_style.dart';

class AppSurface extends StatelessWidget {
  const AppSurface({
    super.key,
    required this.child,
    this.borderRadius,
    this.padding,
    this.width,
    this.height,
    this.role = AppSurfaceRole.surface,
  });

  final Widget child;
  final BorderRadius? borderRadius;
  final EdgeInsetsGeometry? padding;
  final double? width;
  final double? height;
  final AppSurfaceRole role;

  @override
  Widget build(BuildContext context) {
    return AppGlassSurface(
      borderRadius: borderRadius,
      padding: padding,
      width: width,
      height: height,
      role: switch (role) {
        AppSurfaceRole.surface => AppGlassRole.surface,
        AppSurfaceRole.popover => AppGlassRole.popover,
        AppSurfaceRole.control => AppGlassRole.control,
        AppSurfaceRole.bar => AppGlassRole.bar,
        AppSurfaceRole.overlay => AppGlassRole.overlay,
        AppSurfaceRole.mediaOverlay => AppGlassRole.mediaOverlay,
      },
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
  static Future<void>? _initialization;

  static Future<void> initialize() =>
      ensureInitialized(style: AppSurfaceStyle.liquid);

  /// 液体玻璃才需要 shader 预热；flat 启动直接跳过。
  static Future<void> ensureInitialized({required AppSurfaceStyle style}) {
    if (style == AppSurfaceStyle.flat) {
      return Future<void>.value();
    }
    return _initialization ??= AppGlassRuntime.initialize();
  }

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
