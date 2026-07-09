import 'package:flutter/material.dart';
import 'package:sakuramedia/theme.dart';

/// 网格卡/列表行左上角的「选择模式」勾选标记：选中实心对勾，未选半透明空心圈。
///
/// 之前 clip 网格卡、clip 封面卡、合集成员卡各自复制了一份；统一收口到这里。
class SelectionCheckBadge extends StatelessWidget {
  const SelectionCheckBadge({super.key, required this.isSelected});

  final bool isSelected;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Container(
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isSelected
            ? colors.selectionBorder
            : Colors.black.withValues(alpha: 0.35),
        border: Border.all(color: Colors.white, width: 1.5),
      ),
      child: isSelected
          ? const Icon(Icons.check, color: Colors.white, size: 14)
          : null,
    );
  }
}
