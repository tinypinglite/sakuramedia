import 'package:flutter/material.dart';

class AppImageActionTrigger extends StatelessWidget {
  const AppImageActionTrigger({
    super.key,
    required this.child,
    this.onRequestMenu,
    this.onTap,
    this.mouseCursor = SystemMouseCursors.click,
  });

  final Widget child;
  final ValueChanged<Offset>? onRequestMenu;
  final VoidCallback? onTap;
  final MouseCursor mouseCursor;

  @override
  Widget build(BuildContext context) {
    final onRequestMenu = this.onRequestMenu;
    return MouseRegion(
      cursor: mouseCursor,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        onLongPressStart: onRequestMenu == null
            ? null
            : (details) => onRequestMenu(details.globalPosition),
        onSecondaryTapDown: onRequestMenu == null
            ? null
            : (details) => onRequestMenu(details.globalPosition),
        child: child,
      ),
    );
  }
}
