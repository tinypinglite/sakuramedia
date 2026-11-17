import 'package:material_ui/material_ui.dart';

/// macOS 自绘红绿灯（关闭/最小化/缩放）的固定配色。
///
/// 取值为系统真实 sRGB 颜色：常见 SVG 复刻集（lwouis/aw3r1se）里记录的
/// "实测色"实际是把 P3 截图原始值当 sRGB 使用，换算回 sRGB 即经典鲜亮
/// 色系；并用用户机器上的原生截图逐像素取色（含色彩管理转换）交叉验证。
/// 红绿灯不随应用明暗主题变化，因此不做成 ThemeExtension。
@immutable
class AppMacTrafficLightColors {
  const AppMacTrafficLightColors._();

  /// 关闭（红）。
  static const Color closeFill = Color(0xFFFF5F57);
  static const Color closeBorder = Color(0xFFE0443E);
  static const Color closeGlyph = Color(0xFF970000);

  /// 按下时圆点整体变浅。
  static const Color closePressedFill = Color(0xFFFF8D85);

  /// 最小化（黄）。
  static const Color minimizeFill = Color(0xFFFEBC2E);
  static const Color minimizeBorder = Color(0xFFD4A017);
  static const Color minimizeGlyph = Color(0xFFB1710F);
  static const Color minimizePressedFill = Color(0xFFFEEB5A);

  /// 缩放/全屏（绿）。
  static const Color zoomFill = Color(0xFF28C840);
  static const Color zoomBorder = Color(0xFF1AAB29);
  static const Color zoomGlyph = Color(0xFF146300);
  static const Color zoomPressedFill = Color(0xFF53F76B);

  /// 窗口失焦：三个圆点统一变灰，符号只在悬停/按下时出现。
  static const Color inactiveFill = Color(0xFFDDDDDD);
  static const Color inactiveBorder = Color(0xFFD1D0D2);

  /// 失焦悬停符号色（近似值，可按截图微调）。
  static const Color inactiveGlyph = Color(0xFFB0B0B0);
}
