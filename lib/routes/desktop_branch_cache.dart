import 'package:flutter/widgets.dart';

/// Retains the eight most recently visited primary destinations, including
/// their navigators, scroll positions and local UI state. Unvisited pages are
/// not mounted; detail routes are not part of this cache.
class DesktopBranchCache extends StatefulWidget {
  const DesktopBranchCache({
    super.key,
    required this.currentIndex,
    required this.children,
  });

  final int currentIndex;
  final List<Widget> children;

  @override
  State<DesktopBranchCache> createState() => _DesktopBranchCacheState();
}

class _DesktopBranchCacheState extends State<DesktopBranchCache> {
  static const _capacity = 8;
  final _recent = <int>[];

  @override
  void initState() {
    super.initState();
    _visit();
  }

  @override
  void didUpdateWidget(DesktopBranchCache oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentIndex != widget.currentIndex) _visit();
  }

  void _visit() {
    _recent.remove(widget.currentIndex);
    _recent.add(widget.currentIndex);
    if (_recent.length > _capacity) _recent.removeAt(0);
  }

  @override
  Widget build(BuildContext context) => Stack(
    fit: StackFit.expand,
    children: [
      for (final index in _recent)
        Offstage(
          key: ValueKey(index),
          offstage: index != widget.currentIndex,
          child: TickerMode(
            enabled: index == widget.currentIndex,
            child: ExcludeFocus(
              excluding: index != widget.currentIndex,
              child: widget.children[index],
            ),
          ),
        ),
    ],
  );
}
