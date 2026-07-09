import 'package:flutter/material.dart';
import 'package:sakuramedia/theme.dart';

/// 卡片 trailing 区的小尺寸图标按钮:hover 时填充 surfaceMuted 背景,
/// 固定 inline 尺寸(`layoutTokens.inlineActionButtonSize`),
/// 图标走 sm 大小 + secondary tone。设置页/列表行右侧的编辑/删除/同步等
/// 紧凑动作复用此组件。
class AppInlineActionButton extends StatefulWidget {
  const AppInlineActionButton({
    super.key,
    required this.icon,
    required this.onTap,
  });

  final IconData icon;
  final VoidCallback onTap;

  @override
  State<AppInlineActionButton> createState() => _AppInlineActionButtonState();
}

class _AppInlineActionButtonState extends State<AppInlineActionButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final layoutTokens = context.appLayoutTokens;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          width: layoutTokens.inlineActionButtonSize,
          height: layoutTokens.inlineActionButtonSize,
          decoration: BoxDecoration(
            color:
                _hovered ? context.appColors.surfaceMuted : Colors.transparent,
            borderRadius: context.appRadius.smBorder,
          ),
          alignment: Alignment.center,
          child: Icon(
            widget.icon,
            size: context.appComponentTokens.iconSizeSm,
            color: context.appTextPalette.secondary,
          ),
        ),
      ),
    );
  }
}
