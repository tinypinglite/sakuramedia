import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/layout/glass/app_glass_flat_surface.dart';
import 'package:sakuramedia/widgets/base/layout/glass/app_glass_style.dart';
import 'package:sakuramedia/widgets/base/layout/glass/app_glass_types.dart';
import 'package:sakuramedia/widgets/base/layout/surface/app_surface_style.dart';

/// 统一玻璃表面。
///
/// 正常路径按 [AppGlassRole] 从 [AppGlassStyle] 取统一的 iOS 27 regular
/// 配方和 quality；业务页面只选角色、尺寸、圆角与内边距。
///
/// 高对比、关闭模糊或无法映射圆角时走本地 fallback：
/// - 光源固定在顶部中央：顶部最亮，向两侧对称衰减，底部保留一圈很淡的
///   反射光，描边不会在下半圈消失；
/// - 1px 外圈用 sweep 渐变，内层圆角同步减 1px，四角描边均匀；
/// - 内侧顶部叠一层柔和的 specular wash，底部压一道暗边模拟玻璃厚度；
/// - 背景先模糊、再提高饱和度，让玻璃「聚色」而不是发灰。
class AppGlassSurface extends StatelessWidget {
  const AppGlassSurface({
    super.key,
    required this.child,
    this.borderRadius,
    this.padding,
    this.blur = true,
    this.width,
    this.height,
    this.tintOverride,
    this.role = AppGlassRole.surface,
  });

  final Widget child;
  final BorderRadius? borderRadius;
  final EdgeInsetsGeometry? padding;

  /// 是否启用背景滤镜（模糊 + 饱和度提升）。关闭后只保留染色与边光。
  final bool blur;

  /// 整体尺寸；为空时由子级决定。
  final double? width;
  final double? height;

  /// 覆盖当前角色的玻璃染色；为空时使用 [AppGlassStyle] 的角色配方。
  final Color? tintOverride;
  final AppGlassRole role;

  static const double _borderWidth = 1;

  @override
  Widget build(BuildContext context) {
    final radius = borderRadius ?? context.appRadius.mdBorder;
    final highContrast = MediaQuery.maybeHighContrastOf(context) ?? false;

    if (AppSurfaceStyleScope.of(context) == AppSurfaceStyle.flat) {
      return AppGlassFlatSurface(
        borderRadius: radius,
        padding: padding,
        width: width,
        height: height,
        role: AppGlassStyle.flatRoleFor(role),
        child: child,
      );
    }

    if (highContrast) {
      return _buildSolid(context, radius);
    }

    if (blur && !highContrast) {
      final packageSurface = _buildPackageSurface(context, radius);
      if (packageSurface != null) {
        return packageSurface;
      }
    }

    return _buildFallback(
      context,
      radius,
      highContrast: highContrast,
      useFilter: blur && !highContrast,
    );
  }

  Widget? _buildPackageSurface(BuildContext context, BorderRadius radius) {
    final shape = _resolvePackageShape(radius);
    if (shape == null) {
      return null;
    }

    final settings = AppGlassStyle.settingsFor(
      context,
      role,
      tintOverride: tintOverride,
    );
    final quality = AppGlassStyle.qualityFor(role);

    if (!shape.isLeftOnly && !shape.isRightOnly) {
      return GlassContainer(
        width: width,
        height: height,
        padding: padding,
        shape: shape.shape,
        settings: settings,
        quality: quality,
        useOwnLayer: true,
        clipBehavior: Clip.antiAlias,
        child: child,
      );
    }

    final panelWidth = width;
    if (panelWidth == null || !panelWidth.isFinite || panelWidth <= 0) {
      return null;
    }

    final resolvedPadding = (padding ?? EdgeInsets.zero).resolve(
      Directionality.of(context),
    );
    final contentWidth = math.max(0.0, panelWidth - resolvedPadding.horizontal);
    final edgeRadius = shape.isRightOnly ? shape.rightRadius : shape.leftRadius;
    final expandedWidth = panelWidth + edgeRadius;
    final glass = GlassContainer(
      width: expandedWidth,
      height: height,
      padding: padding,
      alignment: shape.isRightOnly
          ? Alignment.centerRight
          : Alignment.centerLeft,
      shape: shape.shape,
      settings: settings,
      quality: quality,
      useOwnLayer: true,
      clipBehavior: Clip.antiAlias,
      child: SizedBox(width: contentWidth, child: child),
    );

    return SizedBox(
      width: panelWidth,
      height: height,
      child: ClipRect(
        clipBehavior: Clip.hardEdge,
        child: OverflowBox(
          alignment: shape.isRightOnly
              ? Alignment.centerRight
              : Alignment.centerLeft,
          minWidth: expandedWidth,
          maxWidth: expandedWidth,
          child: glass,
        ),
      ),
    );
  }

  _PackageShape? _resolvePackageShape(BorderRadius radius) {
    final topLeft = radius.topLeft;
    final topRight = radius.topRight;
    final bottomRight = radius.bottomRight;
    final bottomLeft = radius.bottomLeft;
    final uniform =
        topLeft == topRight &&
        topLeft == bottomRight &&
        topLeft == bottomLeft &&
        topLeft.x == topLeft.y;
    if (uniform) {
      final borderRadius = topLeft.x;
      return _PackageShape(
        shape: LiquidRoundedSuperellipse(borderRadius: borderRadius),
      );
    }

    final topOnly =
        topLeft == topRight &&
        topLeft.x == topLeft.y &&
        bottomLeft == Radius.zero &&
        bottomRight == Radius.zero;
    if (topOnly) {
      return _PackageShape(
        shape: LiquidVerticalRoundedSuperellipse(
          topRadius: topLeft.x,
          bottomRadius: 0,
        ),
      );
    }

    final leftOnly =
        topLeft == bottomLeft &&
        topLeft.x == topLeft.y &&
        topRight == Radius.zero &&
        bottomRight == Radius.zero;
    if (leftOnly) {
      return _PackageShape(
        shape: LiquidRoundedRectangle(borderRadius: topLeft.x),
        leftRadius: topLeft.x,
        isLeftOnly: true,
      );
    }

    final rightOnly =
        topRight == bottomRight &&
        topRight.x == topRight.y &&
        topLeft == Radius.zero &&
        bottomLeft == Radius.zero;
    if (rightOnly) {
      return _PackageShape(
        shape: LiquidRoundedRectangle(borderRadius: topRight.x),
        rightRadius: topRight.x,
        isRightOnly: true,
      );
    }

    return null;
  }

  Widget _buildFallback(
    BuildContext context,
    BorderRadius radius, {
    required bool highContrast,
    required bool useFilter,
  }) {
    final recipe = AppGlassStyle.fallbackRecipe(context, role);
    final highlight = context.appTextPalette.onMedia;
    final tint = tintOverride ?? recipe.tint;
    final tintAlpha = highContrast
        ? math.min(1.0, recipe.tintAlpha + 0.40)
        : recipe.tintAlpha;

    final surface = Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            tint.withValues(alpha: math.min(1.0, tintAlpha * 1.04)),
            tint.withValues(alpha: tintAlpha * 0.96),
          ],
        ),
      ),
      child: Stack(
        children: <Widget>[
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: recipe.topSheenHeight,
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: <Color>[
                      highlight.withValues(alpha: recipe.topSheenAlpha),
                      highlight.withValues(alpha: 0),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            height: _borderWidth * 1.5,
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: <Color>[
                      highlight.withValues(alpha: 0),
                      context.appShadows.color.withValues(
                        alpha: recipe.innerBottomShadowAlpha,
                      ),
                      highlight.withValues(alpha: 0),
                    ],
                    stops: const <double>[0.0, 0.5, 1.0],
                  ),
                ),
              ),
            ),
          ),
          Padding(padding: padding ?? EdgeInsets.zero, child: child),
        ],
      ),
    );

    final glass = Container(
      decoration: BoxDecoration(borderRadius: radius, boxShadow: recipe.shadow),
      child: CustomPaint(
        painter: _GlassRimPainter(
          radius: radius,
          gradient: _rimGradient(highlight, recipe),
          strokeWidth: _borderWidth,
        ),
        child: Padding(
          padding: const EdgeInsets.all(_borderWidth),
          child: ClipRRect(
            borderRadius: _deflateRadius(radius, _borderWidth),
            child: useFilter
                ? BackdropFilter(
                    filter: _backdropFilter(recipe),
                    child: surface,
                  )
                : surface,
          ),
        ),
      ),
    );

    final fallback = KeyedSubtree(
      key: const Key('app-glass-fallback'),
      child: glass,
    );
    if (width == null && height == null) {
      return fallback;
    }
    return SizedBox(width: width, height: height, child: fallback);
  }

  Widget _buildSolid(BuildContext context, BorderRadius radius) {
    final media = role == AppGlassRole.mediaOverlay;
    final surface = DecoratedBox(
      decoration: BoxDecoration(
        color:
            tintOverride ??
            (media
                ? context.appColors.mediaOverlayStrong
                : context.appColors.surfaceElevated),
        borderRadius: radius,
        border: Border.all(
          color: media
              ? context.appColors.highlight.withValues(alpha: 0.38)
              : context.appColors.borderStrong,
        ),
      ),
      child: Padding(padding: padding ?? EdgeInsets.zero, child: child),
    );
    final solid = KeyedSubtree(
      key: const Key('app-glass-solid-surface'),
      child: surface,
    );
    if (width == null && height == null) {
      return solid;
    }
    return SizedBox(width: width, height: height, child: solid);
  }
}

class _PackageShape {
  const _PackageShape({
    required this.shape,
    this.leftRadius = 0,
    this.rightRadius = 0,
    this.isLeftOnly = false,
    this.isRightOnly = false,
  });

  final LiquidShape shape;
  final double leftRadius;
  final double rightRadius;
  final bool isLeftOnly;
  final bool isRightOnly;
}

/// 顶部中央主光 + 左右对称衰减 + 底部微反射。
///
/// 从 topCenter 开始顺时针扫一圈：0.0 顶部最亮，0.25 / 0.75 两侧，
/// 0.5 底部反射。宽扁矩形不会再退化成「左边亮、右边灭」。
SweepGradient _rimGradient(Color highlight, AppGlassFallbackRecipe recipe) {
  final top = highlight.withValues(alpha: recipe.topRimAlpha);
  final side = highlight.withValues(alpha: recipe.sideRimAlpha);
  final low = highlight.withValues(alpha: recipe.lowRimAlpha);
  final bottom = highlight.withValues(alpha: recipe.bottomRimAlpha);
  return SweepGradient(
    center: Alignment.topCenter,
    startAngle: -math.pi / 2,
    endAngle: 3 * math.pi / 2,
    colors: <Color>[top, side, low, bottom, low, side, top],
    stops: const <double>[0.0, 0.22, 0.42, 0.5, 0.58, 0.78, 1.0],
  );
}

ui.ImageFilter _backdropFilter(AppGlassFallbackRecipe recipe) {
  final blur = ui.ImageFilter.blur(
    sigmaX: recipe.blurSigma,
    sigmaY: recipe.blurSigma,
  );
  if (recipe.saturation <= 1.0) {
    return blur;
  }
  return ui.ImageFilter.compose(
    outer: _saturationFilter(recipe.saturation),
    inner: blur,
  );
}

/// 保持亮度权重的饱和度矩阵；玻璃会把背后的颜色「聚」起来。
ui.ColorFilter _saturationFilter(double saturation) {
  const double red = 0.2126;
  const double green = 0.7152;
  const double blue = 0.0722;
  final double inverse = 1.0 - saturation;
  return ui.ColorFilter.matrix(<double>[
    red * inverse + saturation,
    green * inverse,
    blue * inverse,
    0,
    0,
    red * inverse,
    green * inverse + saturation,
    blue * inverse,
    0,
    0,
    red * inverse,
    green * inverse,
    blue * inverse + saturation,
    0,
    0,
    0,
    0,
    0,
    1,
    0,
  ]);
}

BorderRadius _deflateRadius(BorderRadius radius, double delta) {
  Radius deflate(Radius value) => Radius.elliptical(
    math.max(0.0, value.x - delta),
    math.max(0.0, value.y - delta),
  );
  return BorderRadius.only(
    topLeft: deflate(radius.topLeft),
    topRight: deflate(radius.topRight),
    bottomLeft: deflate(radius.bottomLeft),
    bottomRight: deflate(radius.bottomRight),
  );
}

class _GlassRimPainter extends CustomPainter {
  const _GlassRimPainter({
    required this.radius,
    required this.gradient,
    required this.strokeWidth,
  });

  final BorderRadius radius;
  final Gradient gradient;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final rrect = radius.toRRect(rect).deflate(strokeWidth / 2);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..shader = gradient.createShader(rect);
    canvas.drawRRect(rrect, paint);
  }

  @override
  bool shouldRepaint(_GlassRimPainter oldDelegate) {
    return oldDelegate.radius != radius ||
        oldDelegate.gradient != gradient ||
        oldDelegate.strokeWidth != strokeWidth;
  }
}
