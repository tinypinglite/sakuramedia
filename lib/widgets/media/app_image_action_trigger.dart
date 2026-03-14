import 'package:flutter/material.dart';

class AppImageActionTrigger extends StatelessWidget {
  const AppImageActionTrigger({
    super.key,
    required this.child,
    required this.onRequestMenu,
    this.onTap,
    this.mouseCursor = SystemMouseCursors.click,
  });

  final Widget child;
  final ValueChanged<Offset> onRequestMenu;
  final VoidCallback? onTap;
  final MouseCursor mouseCursor;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: mouseCursor,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        onLongPressStart: (details) => onRequestMenu(details.globalPosition),
        onSecondaryTapDown: (details) => onRequestMenu(details.globalPosition),
        child: child,
      ),
    );
  }
}
