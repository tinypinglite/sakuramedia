import 'package:flutter/material.dart';
import 'package:sakuramedia/theme.dart';

/// 移动端筛选底部抽屉的通用壳层：可滚动内容区 + 可选 footer。
///
/// **刻意与桌面 `AppFilterPopover` 的面板结构逐行对齐**——同样是
/// `Flexible(SingleChildScrollView)` 包内容、footer 留在滚动区之外。两端筛选
/// 面板因此是同一套内容 + 同一套行为（即时生效、footer 里重置），只有外层容器
/// 不同：桌面浮层、移动底抽屉。
///
/// 这里**没有标题行、没有确定按钮**：筛选即时生效，不需要提交动作；关闭靠下拉
/// 或点遮罩，与桌面点面板外部收起同义。
class AppMobileFilterDrawerScaffold extends StatelessWidget {
  const AppMobileFilterDrawerScaffold({
    super.key,
    required this.child,
    this.footer,
    this.scrollViewKey,
  });

  final Widget child;

  /// 通常是 `AppFilterPanelFooter`（与桌面面板同一个组件）。
  final Widget? footer;

  final Key? scrollViewKey;

  @override
  Widget build(BuildContext context) {
    final spacing = context.appSpacing;
    final footerWidget = footer;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Flexible(
          child: SingleChildScrollView(
            key: scrollViewKey,
            padding: EdgeInsets.symmetric(vertical: spacing.md),
            child: child,
          ),
        ),
        if (footerWidget != null)
          SafeArea(
            top: false,
            minimum: EdgeInsets.only(top: spacing.sm, bottom: spacing.sm),
            child: footerWidget,
          ),
      ],
    );
  }
}
