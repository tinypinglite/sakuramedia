import 'package:material_ui/material_ui.dart';

/// 播放区是否处于竖屏布局。
///
/// 不能只看 [MediaQuery.orientationOf]：iOS 从横屏切到竖屏后，播放区约束已经
/// 变成竖屏，但播放器子树拿到的 MediaQuery 可能仍是旋转前的横屏尺寸。底栏
/// 紧凑显示必须以实际布局约束为准。
bool isPortraitPlayerViewport(BoxConstraints constraints) {
  return constraints.maxHeight > constraints.maxWidth;
}

/// 播放器控件是否使用紧凑布局。
///
/// 只看播放区实际宽度：旋转过程中 MediaQuery 可能仍停留在旧尺寸，窗口宽度
/// 也可能还没更新；播放区约束已经变窄时就应立即使用紧凑顶栏，避免番号与
/// 旋转/信息按钮挤出屏幕。
bool shouldUseCompactPlayerControls({required BoxConstraints constraints}) {
  return constraints.maxWidth < compactPlayerControlsWidthBreakpoint;
}

/// 紧凑顶栏的宽度阈值。
///
/// 80 = 顶栏左右内缩，422 = 非紧凑内容（返回 44 + 间距 2 + 番号 280 +
/// 旋转 44 + 间距 8 + 信息 44）的宽度，再留少量余量。
const double compactPlayerControlsWidthBreakpoint = 520;
