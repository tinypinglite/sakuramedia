import 'package:material_ui/material_ui.dart';

/// 播放区是否处于竖屏布局。
///
/// 不能只看 [MediaQuery.orientationOf]：iOS 从横屏切到竖屏后，播放区约束已经
/// 变成竖屏，但播放器子树拿到的 MediaQuery 可能仍是旋转前的横屏尺寸。顶栏
/// 紧凑模式和旋转按钮方向都必须以实际布局约束为准。
bool isPortraitPlayerViewport(BoxConstraints constraints) {
  return constraints.maxHeight > constraints.maxWidth;
}

/// 播放器控件是否使用紧凑布局。
///
/// [windowWidth] 仍取窗口宽度，用于桌面窄窗口；[constraints] 取播放区实际
/// 约束，避免 iOS 旋转后 MediaQuery 尺寸滞后把竖屏误判成横屏。
bool shouldUseCompactPlayerControls({
  required BoxConstraints constraints,
  required double windowWidth,
}) {
  return isPortraitPlayerViewport(constraints) || windowWidth < 720;
}
