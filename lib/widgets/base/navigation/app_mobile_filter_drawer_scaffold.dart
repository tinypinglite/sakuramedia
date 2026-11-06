import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/overlays/app_glass_popover.dart';

/// 移动端筛选底部抽屉的通用壳层：可滚动内容区 + 可选 footer。
///
/// **刻意与桌面 `AppGlassFilterPopover` 的面板结构逐行对齐**——同样是
/// `Flexible(SingleChildScrollView)` 包内容、footer 留在滚动区之外。两端筛选
/// 面板因此是同一套内容 + 同一套行为（条件即时更新、footer 里重置），只有外层容器
/// 不同：桌面浮层、移动底抽屉。
///
/// 这里**没有标题行、没有确定按钮**：筛选控件先动，服务端结果由 Provider 防抖
/// 更新；关闭靠下拉或点遮罩，与桌面点面板外部收起同义。
class AppMobileFilterDrawerScaffold extends StatelessWidget {
  const AppMobileFilterDrawerScaffold({
    super.key,
    required this.child,
    this.footer,
    this.scrollViewKey,
  });

  final Widget child;

  /// 通常是 `AppGlassFilterFooter`。
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

/// 移动端筛选抽屉的通用内容：持有筛选状态的本地副本、就地反映选中态并即时向外
/// 应用（不是「等确定的草稿」），footer 里带重置。
///
/// 各 feature 的 `showMobileXxxFilterDrawer` 只需负责弹层参数、Key 和内容构建，
/// 不再各写一份同构的 StatefulWidget。
class AppMobileFilterDrawer<T> extends StatefulWidget {
  const AppMobileFilterDrawer({
    super.key,
    required this.current,
    required this.initial,
    required this.onChanged,
    required this.isDefault,
    required this.scrollViewKey,
    required this.contentBuilder,
    this.extraActive,
    this.onExtraReset,
    this.showResetFooter = true,
  });

  final T current;

  /// 重置按钮恢复到的状态。
  final T initial;
  final ValueChanged<T> onChanged;
  final bool Function(T value) isDefault;
  final Key scrollViewKey;

  /// 构建筛选内容；[onApply] 就地更新本地副本并向外应用。
  final Widget Function(BuildContext context, T local, ValueChanged<T> onApply)
  contentBuilder;

  /// 是否还有筛选值之外的条件生效（如女优页筛选面板里的标签选择）；
  /// 监听它可以让 footer 的默认态与重置可用性实时更新。
  final ValueListenable<bool>? extraActive;

  /// 重置时额外要清掉的条件（如女优页筛选面板里的标签选择）。
  final VoidCallback? onExtraReset;

  /// 为 false 时只保留筛选内容，不显示标准重置 footer。
  final bool showResetFooter;

  @override
  State<AppMobileFilterDrawer<T>> createState() =>
      _AppMobileFilterDrawerState<T>();
}

class _AppMobileFilterDrawerState<T> extends State<AppMobileFilterDrawer<T>> {
  late T _local;

  @override
  void initState() {
    super.initState();
    _local = widget.current;
  }

  void _apply(T next) {
    setState(() => _local = next);
    widget.onChanged(next);
  }

  void _reset() {
    _apply(widget.initial);
    widget.onExtraReset?.call();
  }

  @override
  Widget build(BuildContext context) {
    Widget buildFooter() {
      final extra = widget.extraActive?.value ?? false;
      return AppGlassFilterFooter(
        isDefault: widget.isDefault(_local) && !extra,
        onReset: _reset,
      );
    }

    final extraActive = widget.extraActive;
    return AppMobileFilterDrawerScaffold(
      scrollViewKey: widget.scrollViewKey,
      footer: !widget.showResetFooter
          ? null
          : extraActive == null
          ? buildFooter()
          : ListenableBuilder(
              listenable: extraActive,
              builder: (_, _) => buildFooter(),
            ),
      child: widget.contentBuilder(context, _local, _apply),
    );
  }
}
