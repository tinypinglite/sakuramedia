import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/widgets/base/navigation/app_glass_list_header.dart';
import 'package:sakuramedia/widgets/base/overlays/app_glass_popover.dart';

/// 桌面筛选弹层的唯一高层入口。
///
/// 标准列表只需要提供 trigger 文案、计数信息和面板内容；图片搜索、标签筛选
/// 这类特殊入口可以覆盖 [triggerBuilder] / [footerBuilder]。
class AppGlassFilterPopover extends StatelessWidget {
  const AppGlassFilterPopover({
    super.key,
    required this.panelBuilder,
    this.panelKey,
    this.label,
    this.triggerKey,
    this.tooltip,
    this.info = const <Widget>[],
    this.isDefault = true,
    this.onReset,
    this.resetKey,
    this.showResetFooter = true,
    this.footerBuilder,
    this.triggerBuilder,
    this.onBeforeOpen,
    this.onOpened,
    this.scrollable = false,
    this.scrollViewKey,
    this.enabled = true,
  }) : assert(
         triggerBuilder != null || label != null,
         'AppGlassFilterPopover needs a label or triggerBuilder',
       );

  final WidgetBuilder panelBuilder;
  final Key? panelKey;
  final String? label;
  final Key? triggerKey;
  final String? tooltip;
  final List<Widget> info;
  final bool isDefault;
  final VoidCallback? onReset;
  final Key? resetKey;
  final bool showResetFooter;
  final Widget Function(BuildContext context, VoidCallback close)?
  footerBuilder;
  final Widget Function(BuildContext context, VoidCallback toggle)?
  triggerBuilder;
  final VoidCallback? onBeforeOpen;
  final VoidCallback? onOpened;
  final bool scrollable;
  final Key? scrollViewKey;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return AppGlassPopover(
      panelKey: panelKey,
      scrollable: scrollable,
      scrollViewKey: scrollViewKey,
      onOpened: onOpened,
      triggerBuilder: (context, toggle) {
        final customTrigger = triggerBuilder;
        if (customTrigger != null) {
          return customTrigger(context, toggle);
        }
        return AppGlassFilterGroup(
          buttonKey: triggerKey,
          label: label!,
          tooltip: tooltip,
          onTap: enabled
              ? () {
                  onBeforeOpen?.call();
                  toggle();
                }
              : () {},
          info: info,
        );
      },
      footerBuilder: _resolveFooterBuilder(),
      contentBuilder: (context, close) => panelBuilder(context),
    );
  }

  Widget Function(BuildContext context, VoidCallback close)?
  _resolveFooterBuilder() {
    final customFooterBuilder = footerBuilder;
    if (customFooterBuilder != null) {
      return customFooterBuilder;
    }
    if (!showResetFooter) {
      return null;
    }
    return (context, close) => AppGlassFilterFooter(
      isDefault: isDefault,
      onReset: onReset,
      resetKey: resetKey,
    );
  }
}
