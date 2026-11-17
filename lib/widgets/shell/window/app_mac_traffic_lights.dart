import 'dart:async';

import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/l10n/app_l10n.dart';
import 'package:window_manager/window_manager.dart';

/// 单个圆点的点击区边长（视觉圆 12pt、中心间距 20pt，与系统一致）。
const double appMacTrafficLightButtonSize = 14;

/// 相邻圆点中心间距（与系统一致）。
const double appMacTrafficLightSpacing = 20;

/// 视觉圆直径。
const double appMacTrafficLightCircleSize = 12;

/// close 圆点中心距窗口左缘：对齐侧栏菜单图标中心
///（8pt 侧栏边距 + 12pt 菜单项内边距 + 9pt 图标半宽 = 29pt）。
const double _closeCenterX = 29;

/// 红绿灯组左缘在窗口坐标系中的位置（22pt，组右缘到 76pt）。
const double appMacTrafficLightsLeft =
    _closeCenterX - appMacTrafficLightButtonSize / 2;

enum _TrafficLightGlyph { close, minimize, zoomExpand, zoomPlus }

/// macOS 自绘红绿灯（关闭/最小化/缩放）。
///
/// 系统原生按钮已隐藏（WindowOptions.windowButtonVisibility = false），
/// 视觉与交互在这里实现：悬停/按下显示符号、按下变浅、窗口失焦变灰；
/// 绿色默认悬停显示两个三角的展开符号（左上◤+右下◢，Tahoe 方向），
/// 按住 Option 时换成 "+"（对应 option+点击=缩放），默认点击切换全屏。
class AppMacTrafficLights extends StatefulWidget {
  const AppMacTrafficLights({super.key});

  @override
  State<AppMacTrafficLights> createState() => _AppMacTrafficLightsState();
}

class _AppMacTrafficLightsState extends State<AppMacTrafficLights>
    with WindowListener {
  bool _windowFocused = true;
  bool _hovered = false;
  bool _optionHeld = false;
  int? _pressedIndex;

  @override
  void initState() {
    super.initState();
    windowManager.addListener(this);
    HardwareKeyboard.instance.addHandler(_handleKeyEvent);
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_handleKeyEvent);
    windowManager.removeListener(this);
    super.dispose();
  }

  bool _handleKeyEvent(KeyEvent event) {
    final optionHeld = HardwareKeyboard.instance.isAltPressed;
    if (optionHeld != _optionHeld) {
      setState(() => _optionHeld = optionHeld);
    }
    return false;
  }

  @override
  void onWindowFocus() {
    if (!_windowFocused) {
      setState(() => _windowFocused = true);
    }
  }

  @override
  void onWindowBlur() {
    if (_windowFocused) {
      setState(() => _windowFocused = false);
    }
  }

  void _close() {
    unawaited(windowManager.close());
  }

  void _minimize() {
    unawaited(windowManager.minimize());
  }

  Future<void> _zoom() async {
    if (HardwareKeyboard.instance.isAltPressed) {
      if (await windowManager.isMaximized()) {
        await windowManager.unmaximize();
      } else {
        await windowManager.maximize();
      }
      return;
    }
    await windowManager.setFullScreen(!await windowManager.isFullScreen());
  }

  @override
  Widget build(BuildContext context) {
    final l10n = appL10n(context);
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: Row(
        key: const Key('mac-traffic-lights'),
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildButton(
            index: 0,
            key: const Key('mac-traffic-light-close'),
            label: l10n.shellWindowClose,
            fill: AppMacTrafficLightColors.closeFill,
            border: AppMacTrafficLightColors.closeBorder,
            glyph: _TrafficLightGlyph.close,
            glyphColor: AppMacTrafficLightColors.closeGlyph,
            pressedFill: AppMacTrafficLightColors.closePressedFill,
            onTap: _close,
          ),
          const SizedBox(
            width: appMacTrafficLightSpacing - appMacTrafficLightButtonSize,
          ),
          _buildButton(
            index: 1,
            key: const Key('mac-traffic-light-minimize'),
            label: l10n.shellWindowMinimize,
            fill: AppMacTrafficLightColors.minimizeFill,
            border: AppMacTrafficLightColors.minimizeBorder,
            glyph: _TrafficLightGlyph.minimize,
            glyphColor: AppMacTrafficLightColors.minimizeGlyph,
            pressedFill: AppMacTrafficLightColors.minimizePressedFill,
            onTap: _minimize,
          ),
          const SizedBox(
            width: appMacTrafficLightSpacing - appMacTrafficLightButtonSize,
          ),
          _buildButton(
            index: 2,
            key: const Key('mac-traffic-light-zoom'),
            label: l10n.shellWindowFullscreen,
            fill: AppMacTrafficLightColors.zoomFill,
            border: AppMacTrafficLightColors.zoomBorder,
            glyph: _optionHeld
                ? _TrafficLightGlyph.zoomPlus
                : _TrafficLightGlyph.zoomExpand,
            glyphColor: AppMacTrafficLightColors.zoomGlyph,
            pressedFill: AppMacTrafficLightColors.zoomPressedFill,
            onTap: _zoom,
          ),
        ],
      ),
    );
  }

  Widget _buildButton({
    required int index,
    required Key key,
    required String label,
    required Color fill,
    required Color border,
    required _TrafficLightGlyph glyph,
    required Color glyphColor,
    required Color pressedFill,
    required VoidCallback onTap,
  }) {
    final pressed = _pressedIndex == index;
    final Color resolvedFill;
    final Color resolvedBorder;
    final Color resolvedGlyph;
    if (!_windowFocused) {
      resolvedFill = AppMacTrafficLightColors.inactiveFill;
      resolvedBorder = AppMacTrafficLightColors.inactiveBorder;
      resolvedGlyph = AppMacTrafficLightColors.inactiveGlyph;
    } else {
      // 按下时圆点整体变浅，描边与符号色不变。
      resolvedFill = pressed ? pressedFill : fill;
      resolvedBorder = border;
      resolvedGlyph = glyphColor;
    }
    final showGlyph = _hovered || pressed;

    return Semantics(
      button: true,
      label: label,
      child: GestureDetector(
        key: key,
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => setState(() => _pressedIndex = index),
        onTapUp: (_) => setState(() => _pressedIndex = null),
        onTapCancel: () => setState(() => _pressedIndex = null),
        onTap: onTap,
        child: SizedBox(
          width: appMacTrafficLightButtonSize,
          height: appMacTrafficLightButtonSize,
          child: Center(
            child: Container(
              width: appMacTrafficLightCircleSize,
              height: appMacTrafficLightCircleSize,
              decoration: BoxDecoration(
                color: resolvedFill,
                shape: BoxShape.circle,
                border: Border.all(color: resolvedBorder, width: 0.5),
              ),
              child: showGlyph
                  ? Center(
                      child: CustomPaint(
                        key: Key('mac-traffic-light-glyph-${glyph.name}'),
                        size: const Size(
                          appMacTrafficLightCircleSize,
                          appMacTrafficLightCircleSize,
                        ),
                        painter: _TrafficLightGlyphPainter(
                          glyph,
                          resolvedGlyph,
                        ),
                      ),
                    )
                  : null,
            ),
          ),
        ),
      ),
    );
  }
}

/// 符号几何按系统原生 SVG（viewBox 85.4 = 12pt，×0.1405）换算到
/// 以圆心为原点的 pt 坐标。
class _TrafficLightGlyphPainter extends CustomPainter {
  const _TrafficLightGlyphPainter(this.glyph, this.color);

  final _TrafficLightGlyph glyph;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    switch (glyph) {
      case _TrafficLightGlyph.close:
        // 两条对角线，线段半程 2.475pt、线宽 0.70pt，圆头。
        final paint = _strokePaint(0.70);
        canvas.drawLine(
          center.translate(-2.475, -2.475),
          center.translate(2.475, 2.475),
          paint,
        );
        canvas.drawLine(
          center.translate(-2.475, 2.475),
          center.translate(2.475, -2.475),
          paint,
        );
      case _TrafficLightGlyph.minimize:
        // 线段 ±3.5pt + 圆头 ⇒ 视觉总长 8pt、粗 1.0pt。
        canvas.drawLine(
          center.translate(-3.5, 0),
          center.translate(3.5, 0),
          _strokePaint(1.0),
        );
      case _TrafficLightGlyph.zoomPlus:
        final paint = _strokePaint(1.0);
        canvas.drawLine(
          center.translate(-2.5, 0),
          center.translate(2.5, 0),
          paint,
        );
        canvas.drawLine(
          center.translate(0, -2.5),
          center.translate(0, 2.5),
          paint,
        );
      case _TrafficLightGlyph.zoomExpand:
        // 左上◤ + 右下◢ 两个直角三角：腿 4.67pt、直角圆角 0.9pt、
        // 对角缝隙约 2.1pt（Tahoe 原生方向）。
        final paint = Paint()..color = color;
        canvas.drawPath(_topLeftTriangle(center), paint);
        canvas.drawPath(_bottomRightTriangle(center), paint);
    }
  }

  Paint _strokePaint(double width) => Paint()
    ..color = color
    ..strokeWidth = width
    ..strokeCap = StrokeCap.round;

  Path _topLeftTriangle(Offset center) => Path()
    ..moveTo(center.dx + 1.59, center.dy - 3.08)
    ..lineTo(center.dx - 2.18, center.dy - 3.08)
    ..quadraticBezierTo(
      center.dx - 3.08,
      center.dy - 3.08,
      center.dx - 3.08,
      center.dy - 2.18,
    )
    ..lineTo(center.dx - 3.08, center.dy + 1.59)
    ..close();

  Path _bottomRightTriangle(Offset center) => Path()
    ..moveTo(center.dx - 1.59, center.dy + 3.08)
    ..lineTo(center.dx + 2.18, center.dy + 3.08)
    ..quadraticBezierTo(
      center.dx + 3.08,
      center.dy + 3.08,
      center.dx + 3.08,
      center.dy + 2.18,
    )
    ..lineTo(center.dx + 3.08, center.dy - 1.59)
    ..close();

  @override
  bool shouldRepaint(covariant _TrafficLightGlyphPainter oldDelegate) =>
      oldDelegate.glyph != glyph || oldDelegate.color != color;
}
