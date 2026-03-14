import 'package:flutter/material.dart';
import 'package:sakuramedia/widgets/actions/app_icon_button.dart';

class ImageSearchToolbarIconButton extends StatelessWidget {
  const ImageSearchToolbarIconButton({
    super.key,
    required this.tooltip,
    required this.icon,
    this.onPressed,
    this.isSelected = false,
  });

  final String tooltip;
  final Widget icon;
  final VoidCallback? onPressed;
  final bool isSelected;

  @override
  Widget build(BuildContext context) {
    return AppIconButton(
      tooltip: tooltip,
      icon: icon,
      onPressed: onPressed,
      isSelected: isSelected,
      size: AppIconButtonSize.regular,
    );
  }
}
