import 'package:flutter/material.dart';
import 'package:multi_split_view/multi_split_view.dart';
import 'package:sakuramedia/theme.dart';

/// 合集连播页的左右分栏壳：左 72% 放播放器（含「选集」浮层），右 28% 放「整部合集」
/// 关键帧面板。语义对齐 jav 播放页的 `_MoviePlayerSplitLayout`，但**独立实现**——
/// jav 播放页不迁移（避免动其稳定 Key / 测试），两个合集连播页共用本壳。
///
/// 自持 [MultiSplitViewController]（在 [State] 内创建并释放），调用方只传左右子树。
class CollectionPlaySplitLayout extends StatefulWidget {
  const CollectionPlaySplitLayout({
    super.key,
    required this.keyPrefix,
    required this.left,
    required this.right,
  });

  /// 区分两个合集页的 Key 前缀（如 `clip-collection` / `video-collection`）。
  final String keyPrefix;
  final Widget left;
  final Widget right;

  @override
  State<CollectionPlaySplitLayout> createState() =>
      _CollectionPlaySplitLayoutState();
}

class _CollectionPlaySplitLayoutState extends State<CollectionPlaySplitLayout> {
  late final MultiSplitViewController _controller;

  @override
  void initState() {
    super.initState();
    _controller = MultiSplitViewController(
      areas: <Area>[Area(flex: 0.72), Area(flex: 0.28)],
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiSplitViewTheme(
      data: MultiSplitViewThemeData(
        dividerThickness: context.appSpacing.xs,
        dividerPainter: DividerPainters.grooved1(
          color: context.appColors.borderSubtle,
        ),
      ),
      child: MultiSplitView(
        controller: _controller,
        axis: Axis.horizontal,
        builder:
            (context, area) =>
                area.index == 0
                    ? _PlayerPanel(keyPrefix: widget.keyPrefix, child: widget.left)
                    : _SidePanel(keyPrefix: widget.keyPrefix, child: widget.right),
      ),
    );
  }
}

class _PlayerPanel extends StatelessWidget {
  const _PlayerPanel({required this.keyPrefix, required this.child});

  final String keyPrefix;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      key: Key('$keyPrefix-play-left-panel'),
      borderRadius: context.appRadius.lgBorder,
      child: ColoredBox(color: Colors.black, child: child),
    );
  }
}

class _SidePanel extends StatelessWidget {
  const _SidePanel({required this.keyPrefix, required this.child});

  final String keyPrefix;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: Key('$keyPrefix-play-filmstrip-panel'),
      decoration: BoxDecoration(
        color: context.appColors.surfaceCard,
        borderRadius: context.appRadius.xsBorder,
        border: Border.all(color: context.appColors.borderSubtle),
      ),
      child: child,
    );
  }
}
