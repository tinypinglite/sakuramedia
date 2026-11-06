import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

/// 玻璃质量的语义意图。
///
/// 这里定义的是“这个角色希望用哪一档”，不是最终生效档位。根部的
/// `GlassAdaptiveScope` 会按设备实测帧耗时把所有档位统一 cap 到合适的上限。
///
/// 业务代码不要直接写 `GlassQuality.premium` / `standard` / `minimal`；
/// 需要调整全局画质策略时只改本文件。
abstract final class AppGlassQuality {
  /// 自适应范围的下限和上限。
  static const GlassQuality minimum = GlassQuality.minimal;
  static const GlassQuality maximum = GlassQuality.premium;

  /// 桌面侧栏：面积大，优先保流畅。
  static const GlassQuality sidebar = GlassQuality.standard;

  /// 分段控件等控件内部的凹槽。
  static const GlassQuality track = GlassQuality.standard;

  /// 页面内可点击的次级控件。
  static const GlassQuality control = GlassQuality.premium;

  /// 浮在媒体内容上的窗口级控件（顶栏、浮动返回键）。
  static const GlassQuality chrome = GlassQuality.premium;

  /// 播放器菜单/抽屉等媒体浮层。
  static const GlassQuality overlay = GlassQuality.premium;

  /// 对话框、底部抽屉等模态浮层。
  static const GlassQuality modal = GlassQuality.premium;

  /// 文本输入框。
  static const GlassQuality input = GlassQuality.premium;

  /// 移动端底部导航。
  static const GlassQuality navigation = GlassQuality.premium;

  /// 导航栏和浮层里的圆形图标按钮。
  static const GlassQuality iconButton = GlassQuality.premium;

  /// 玻璃控制条里的一组按钮。
  static const GlassQuality groupedActions = GlassQuality.premium;

  /// 分段控件。
  static const GlassQuality segmentedControl = GlassQuality.standard;

  /// 筛选/排序弹层。
  static const GlassQuality popover = GlassQuality.minimal;

  /// 弹层内部的次级动作按钮。
  static const GlassQuality popoverAction = GlassQuality.standard;

  /// Toast。
  static const GlassQuality toast = GlassQuality.standard;

  /// 合集卡片上的信息条。
  static const GlassQuality collectionBadge = GlassQuality.minimal;
}
