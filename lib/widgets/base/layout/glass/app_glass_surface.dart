import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/theme.dart';

/// 玻璃材质的语义档位：
/// - [chrome]：浮在媒体内容上的窗口级控件（顶栏、浮动返回键），带浮层阴影；
/// - [control]：页面内的可点击次级控件（动作组），主题自适应、不带阴影；
/// - [overlay]：播放器菜单/抽屉等深色媒体浮层，模糊更强、染色更实；
/// - [track]：分段控件等控件内部的凹槽，只提供一层很淡的玻璃底和边光。
///
/// 内容卡和正文不使用玻璃，保持可读性；主操作仍用实色品牌色。
enum AppGlassTone { chrome, control, overlay, track }

/// 统一玻璃表面。
///
/// 参考 iOS Liquid Glass 与 ColorOS 光场设计的共同点：玻璃不是
/// 「半透明色 + 一条白边」，而是有厚度的透镜。配方固定在这里，业务页面
/// 只选 tone / 尺寸 / 圆角 / 内边距：
/// - 光源固定在顶部中央：顶部最亮，向两侧对称衰减，底部保留一圈很淡的
///   反射光，描边不会在下半圈消失；
/// - 1px 外圈用 sweep 渐变，内层圆角同步减 1px，四角描边均匀；
/// - 内侧顶部叠一层柔和的 specular wash，底部压一道暗边模拟玻璃厚度；
/// - 背景先模糊、再提高饱和度，让玻璃「聚色」而不是发灰；
/// - chrome / overlay 带浮层阴影，control / track 不带阴影。
///
/// 真实折射需要 Impeller fragment shader；这里用光感近似，避免跨平台风险。
class AppGlassSurface extends StatelessWidget {
  const AppGlassSurface({
    super.key,
    required this.child,
    this.tone = AppGlassTone.control,
    this.borderRadius,
    this.padding,
    this.blur = true,
    this.width,
    this.height,
  });

  final Widget child;
  final AppGlassTone tone;
  final BorderRadius? borderRadius;
  final EdgeInsetsGeometry? padding;

  /// 是否启用背景滤镜（模糊 + 饱和度提升）。关闭后只保留染色与边光。
  final bool blur;

  /// 整体尺寸（包含 1px 外圈描边）；为空时由子级决定。
  final double? width;
  final double? height;

  static const double _borderWidth = 1;

  @override
  Widget build(BuildContext context) {
    final recipe = _GlassRecipe.resolve(context, tone);
    final radius = borderRadius ?? context.appRadius.mdBorder;
    final highlight = context.appTextPalette.onMedia;
    final highContrast = MediaQuery.maybeHighContrastOf(context) ?? false;
    final tintAlpha = highContrast
        ? math.min(1.0, recipe.tintAlpha + 0.40)
        : recipe.tintAlpha;
    final useFilter = blur && !highContrast;

    final surface = Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            recipe.tint.withValues(alpha: math.min(1.0, tintAlpha * 1.04)),
            recipe.tint.withValues(alpha: tintAlpha * 0.96),
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
                      Colors.transparent,
                      context.appShadows.color.withValues(
                        alpha: recipe.innerBottomShadowAlpha,
                      ),
                      Colors.transparent,
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

    if (width == null && height == null) {
      return glass;
    }
    return SizedBox(width: width, height: height, child: glass);
  }
}

/// 顶部中央主光 + 左右对称衰减 + 底部微反射。
///
/// 从 topCenter 开始顺时针扫一圈：0.0 顶部最亮，0.25 / 0.75 两侧，
/// 0.5 底部反射。宽扁矩形不会再退化成「左边亮、右边灭」。
SweepGradient _rimGradient(Color highlight, _GlassRecipe recipe) {
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

ui.ImageFilter _backdropFilter(_GlassRecipe recipe) {
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

class _GlassRecipe {
  const _GlassRecipe({
    required this.tint,
    required this.tintAlpha,
    required this.blurSigma,
    required this.saturation,
    required this.topRimAlpha,
    required this.sideRimAlpha,
    required this.lowRimAlpha,
    required this.bottomRimAlpha,
    required this.topSheenAlpha,
    required this.topSheenHeight,
    required this.innerBottomShadowAlpha,
    this.shadow,
  });

  final Color tint;
  final double tintAlpha;
  final double blurSigma;
  final double saturation;
  final double topRimAlpha;
  final double sideRimAlpha;
  final double lowRimAlpha;
  final double bottomRimAlpha;
  final double topSheenAlpha;
  final double topSheenHeight;
  final double innerBottomShadowAlpha;
  final List<BoxShadow>? shadow;

  static _GlassRecipe resolve(BuildContext context, AppGlassTone tone) {
    final colors = context.appColors;
    final overlay = context.appOverlayTokens;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return switch (tone) {
      AppGlassTone.chrome => _GlassRecipe(
        tint: colors.mediaOverlayStrong,
        tintAlpha: 0.38,
        blurSigma: 18,
        saturation: 1.18,
        topRimAlpha: 0.55,
        sideRimAlpha: 0.20,
        lowRimAlpha: 0.06,
        bottomRimAlpha: 0.12,
        topSheenAlpha: 0.14,
        topSheenHeight: 22,
        innerBottomShadowAlpha: 0.20,
        shadow: context.appShadows.panel,
      ),
      AppGlassTone.control => _GlassRecipe(
        tint: colors.surfaceElevated,
        tintAlpha: 0.44,
        blurSigma: 18,
        saturation: 1.12,
        topRimAlpha: 0.52,
        sideRimAlpha: 0.20,
        lowRimAlpha: 0.05,
        bottomRimAlpha: 0.10,
        topSheenAlpha: 0.14,
        topSheenHeight: 20,
        innerBottomShadowAlpha: isDark ? 0.20 : 0.08,
      ),
      AppGlassTone.overlay => _GlassRecipe(
        tint: colors.movieDetailHeroBackgroundStart,
        tintAlpha: overlay.glassSurfaceAlpha,
        blurSigma: overlay.glassBlurSigma,
        saturation: 1.10,
        topRimAlpha: 0.40,
        sideRimAlpha: overlay.surfaceBorderAlpha,
        lowRimAlpha: 0.05,
        bottomRimAlpha: 0.10,
        topSheenAlpha: 0.10,
        topSheenHeight: 20,
        innerBottomShadowAlpha: 0.24,
        shadow: <BoxShadow>[
          BoxShadow(
            color: context.appShadows.color.withValues(
              alpha: overlay.surfaceShadowAlpha,
            ),
            blurRadius: overlay.surfaceShadowBlur,
            offset: Offset(0, overlay.surfaceShadowOffsetY),
          ),
        ],
      ),
      AppGlassTone.track => _GlassRecipe(
        tint: colors.mediaOverlaySoft,
        tintAlpha: 0.10,
        blurSigma: 10,
        saturation: 1.0,
        topRimAlpha: 0.35,
        sideRimAlpha: 0.12,
        lowRimAlpha: 0.04,
        bottomRimAlpha: 0.06,
        topSheenAlpha: 0.08,
        topSheenHeight: 14,
        innerBottomShadowAlpha: 0.10,
      ),
    };
  }
}
