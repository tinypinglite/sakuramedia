import 'package:flutter/material.dart';

class AppImageActionTrigger extends StatelessWidget {
  const AppImageActionTrigger({
    super.key,
    required this.child,
    this.onRequestMenu,
    this.onTap,
    this.onTapAt,
    this.mouseCursor = SystemMouseCursors.click,
  });

  final Widget child;
  final ValueChanged<Offset>? onRequestMenu;
  final VoidCallback? onTap;
  final ValueChanged<Offset>? onTapAt;
  final MouseCursor mouseCursor;

  @override
  Widget build(BuildContext context) {
    Offset? tapPosition;
    final onRequestMenu = this.onRequestMenu;
    return MouseRegion(
      cursor: mouseCursor,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: onTapAt == null
            ? null
            : (details) => tapPosition = details.localPosition,
        onTap: onTapAt == null
            ? onTap
            : () => onTapAt!(tapPosition ?? Offset.zero),
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
