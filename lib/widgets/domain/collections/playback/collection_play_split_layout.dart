import 'package:material_ui/material_ui.dart';
import 'package:multi_split_view/multi_split_view.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/domain/media/collapsible_player_split_view.dart';

/// 合集连播页的左右分栏壳：左 72% 放播放器（含「选集」浮层），右 28% 放「整部合集」
/// 关键帧面板。语义对齐 jav 播放页的 `_MoviePlayerSplitLayout`，但**独立实现**——
/// jav 播放页不迁移（避免动其稳定 Key / 测试），两个合集连播页共用本壳。
///
/// 自持 [MultiSplitViewController]（在 [State] 内创建并释放），调用方只传左右子树。
/// [collapsible] 为 true 时右面板默认展开，右上角常显开关可收起/再展开，展开后仍可拖宽。
class CollectionPlaySplitLayout extends StatefulWidget {
  const CollectionPlaySplitLayout({
    super.key,
    required this.keyPrefix,
    required this.left,
    required this.right,
    this.collapsible = false,
    this.panelAvailable = true,
  });

  /// 区分两个合集页的 Key 前缀（如 `clip-collection` / `video-collection`）。
  final String keyPrefix;
  final Widget left;
  final Widget right;

  /// 传 true：右侧面板默认展开，显示右上角常显开关。
  final bool collapsible;

  /// 右侧面板是否有内容可展示；无内容时不显示开关。
  final bool panelAvailable;

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
    return CollapsiblePlayerSplitView(
      controller: _controller,
      collapsible: widget.collapsible,
      panelAvailable: widget.panelAvailable,
      handleKey: Key('${widget.keyPrefix}-panel-handle'),
      leftBuilder: (context) =>
          _PlayerPanel(keyPrefix: widget.keyPrefix, child: widget.left),
      rightBuilder: (context) =>
          _SidePanel(keyPrefix: widget.keyPrefix, child: widget.right),
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
