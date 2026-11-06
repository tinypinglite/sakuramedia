import 'package:material_ui/material_ui.dart';

/// 给非滚动内容补齐底部安全区。
///
/// 滚动页面继续使用 `bottomSafeAreaSliver` / `AppAdaptiveRefreshScrollView`；
/// 固定在底部的表单、空态和设置内容用这个包裹，避免最后一行被 home indicator
/// 或根 Tab 玻璃底栏压住。[extra] 用来叠加业务自己的底部操作条高度。
class AppBottomSafeAreaPadding extends StatelessWidget {
  const AppBottomSafeAreaPadding({
    super.key,
    required this.child,
    this.extra = 0,
  }) : assert(extra >= 0);

  final Widget child;
  final double extra;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.paddingOf(context).bottom + extra,
      ),
      child: child,
    );
  }
}
