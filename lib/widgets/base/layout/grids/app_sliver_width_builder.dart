import 'package:material_ui/material_ui.dart';

typedef AppSliverWidthWidgetBuilder =
    Widget Function(BuildContext context, double width);

/// 只在 cross-axis 宽度变化时重建目标 sliver。
///
/// [SliverLayoutBuilder] 会在滚动时收到不断变化的 [SliverConstraints]
/// （`scrollOffset`、缓存区范围等），直接在其中返回新的 [SliverList] /
/// [SliverGrid] 会让当前已挂载的子项每帧重建。这里的构建只依赖宽度，
/// 因此按宽度缓存目标 sliver；滚动时返回同一个 Widget 实例，框架会走
/// no-op update 路径，不会重建子项。
///
/// 父级重建时会清空缓存，确保新的 items、回调或主题 token 能生效。
class AppSliverWidthBuilder extends StatefulWidget {
  const AppSliverWidthBuilder({super.key, required this.builder});

  final AppSliverWidthWidgetBuilder builder;

  @override
  State<AppSliverWidthBuilder> createState() => _AppSliverWidthBuilderState();
}

class _AppSliverWidthBuilderState extends State<AppSliverWidthBuilder> {
  double? _cachedWidth;
  Widget? _cachedSliver;

  @override
  Widget build(BuildContext context) {
    _cachedWidth = null;
    _cachedSliver = null;
    return SliverLayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.crossAxisExtent;
        final cachedSliver = _cachedSliver;
        if (cachedSliver != null && _cachedWidth == width) {
          return cachedSliver;
        }
        final sliver = widget.builder(context, width);
        _cachedWidth = width;
        _cachedSliver = sliver;
        return sliver;
      },
    );
  }
}
