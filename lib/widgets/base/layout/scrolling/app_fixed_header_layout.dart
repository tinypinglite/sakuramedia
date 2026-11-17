import 'package:material_ui/material_ui.dart';

/// 列表控制栏占据自身高度，结果区使用剩余空间独立滚动。
class AppFixedHeaderLayout extends StatelessWidget {
  const AppFixedHeaderLayout({
    super.key,
    required this.header,
    required this.child,
    this.headerBottomSpacing = 0,
  }) : assert(headerBottomSpacing >= 0);

  final Widget header;

  /// 固定 header 与滚动区之间的持久留白。
  ///
  /// 筛选类控制栏应把间距放在这里，而不是滚动内容的首个 sliver；后者会随列表
  /// 滚走，导致内容贴住控制栏。
  final double headerBottomSpacing;

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        header,
        if (headerBottomSpacing > 0) SizedBox(height: headerBottomSpacing),
        Expanded(child: child),
      ],
    );
  }
}
