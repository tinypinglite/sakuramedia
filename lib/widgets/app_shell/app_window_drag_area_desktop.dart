import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

class AppWindowDragArea extends StatelessWidget {
  const AppWindowDragArea({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DragToMoveArea(child: child);
  }
}
