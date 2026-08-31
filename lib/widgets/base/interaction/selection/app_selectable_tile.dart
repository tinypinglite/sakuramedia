import 'package:flutter/material.dart';
import 'package:sakuramedia/theme.dart';

/// 「可选中卡片」外壳：InkWell + AnimatedContainer(120ms) 圆角边框卡，
/// 选中态自动切换 `selectionSurface/selectionBorder`，未选态用 `surfaceMuted/borderSubtle`。
///
/// 只承载外壳视觉，`child` 自行组装（Checkbox/Radio + 内容都由 caller 塞）。
/// 之前媒体管理页 `_MediaRow`（多选）与秒传目标库对话框 `_LibraryTile`（单选）
/// 各自手写同一段 Material→InkWell→AnimatedContainer 模板；统一收口到这里。
class AppSelectableTile extends StatelessWidget {
  const AppSelectableTile({
    super.key,
    required this.selected,
    required this.onTap,
    required this.child,
    this.padding,
  });

  final bool selected;
  final VoidCallback onTap;
  final Widget child;

  /// 默认 `EdgeInsets.all(spacing.md)`。
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: context.appRadius.mdBorder,
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          padding: padding ?? EdgeInsets.all(context.appSpacing.md),
          decoration: BoxDecoration(
            color: selected ? colors.selectionSurface : colors.surfaceMuted,
            borderRadius: context.appRadius.mdBorder,
            border: Border.all(
              color: selected ? colors.selectionBorder : colors.borderSubtle,
            ),
          ),
          child: child,
        ),
      ),
    );
  }
}
