import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/theme.dart';

/// 电视端整页卡片网格：按屏幕宽度取 TV 列数，卡片填满网格单元。
class TvCardGrid<T> extends StatelessWidget {
  const TvCardGrid({
    super.key,
    this.gridKey,
    required this.items,
    required this.itemBuilder,
    this.controller,
    this.childAspectRatio,
  });

  final Key? gridKey;
  final List<T> items;
  final Widget Function(BuildContext context, T item) itemBuilder;
  final ScrollController? controller;

  /// 卡片宽高比；默认与全站影片卡一致。
  final double? childAspectRatio;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = AppTvTokens.gridColumnsForWidth(constraints.maxWidth);
        return GridView.builder(
          key: gridKey,
          controller: controller,
          gridDelegate: _tvGridDelegate(context, columns, childAspectRatio),
          itemCount: items.length,
          itemBuilder: (context, index) => itemBuilder(context, items[index]),
        );
      },
    );
  }
}

/// 电视端整页卡片网格的 Sliver 版本，供整页 `CustomScrollView` 直接使用。
class TvCardSliverGrid<T> extends StatelessWidget {
  const TvCardSliverGrid({
    super.key,
    this.gridKey,
    required this.items,
    required this.itemBuilder,
    this.childAspectRatio,
  });

  final Key? gridKey;
  final List<T> items;
  final Widget Function(BuildContext context, T item) itemBuilder;
  final double? childAspectRatio;

  @override
  Widget build(BuildContext context) {
    return SliverLayoutBuilder(
      builder: (context, constraints) {
        final columns = AppTvTokens.gridColumnsForWidth(
          constraints.crossAxisExtent,
        );
        return SliverGrid(
          key: gridKey,
          gridDelegate: _tvGridDelegate(context, columns, childAspectRatio),
          delegate: SliverChildBuilderDelegate(
            (context, index) => itemBuilder(context, items[index]),
            childCount: items.length,
          ),
        );
      },
    );
  }
}

SliverGridDelegateWithFixedCrossAxisCount _tvGridDelegate(
  BuildContext context,
  int columns,
  double? childAspectRatio,
) {
  return SliverGridDelegateWithFixedCrossAxisCount(
    crossAxisCount: columns,
    crossAxisSpacing: AppTvTokens.gridGap,
    mainAxisSpacing: AppTvTokens.gridGap,
    childAspectRatio:
        childAspectRatio ?? context.appComponentTokens.movieCardAspectRatio,
  );
}
