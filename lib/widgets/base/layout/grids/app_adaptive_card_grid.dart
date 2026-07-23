import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/feedback/app_empty_state.dart';

/// 布局模式：等宽 tile(固定 aspect ratio) vs 瀑布流(逐 tile aspect)。
enum AppAdaptiveCardGridLayout { fixedAspect, masonry }

/// 自适应四态卡片网格：**骨架 → 错误 → 空态 → 内容**。
///
/// 消除 movies / actors / rankings / videos 四份网格的 copy-paste:
/// - 列数按 `((width + spacing) / (targetWidth + spacing)).floor()` 计算,
///   钳位到 [minColumns, maxColumns]；
/// - `layout: fixedAspect` 走 [GridView] + [childAspectRatio]；
/// - `layout: masonry` 走 [MasonryGridView] + [tileAspect]（每 tile 自算高度）。
///
/// 骨架卡由 caller 提供 [skeletonBuilder]（各域视觉差异较大,不统一）。
/// 内容 tile 走 [itemBuilder]，泛型 [T] 由 caller 决定。
///
/// 本组件只适合固定少量、嵌入其它滚动区的预览内容。累计分页页面必须使用
/// [AppAdaptiveCardSliver]，否则 `shrinkWrap` 会为计算完整高度而布局全部条目。
class AppAdaptiveCardGrid<T> extends StatelessWidget {
  const AppAdaptiveCardGrid({
    super.key,
    this.gridKey,
    required this.items,
    required this.isLoading,
    required this.itemBuilder,
    required this.skeletonBuilder,
    this.errorMessage,
    this.emptyMessage = '当前没有可展示的数据。',
    this.placeholderCount = 8,
    this.targetColumnWidth,
    this.minColumns = 2,
    this.maxColumns = 6,
    this.layout = AppAdaptiveCardGridLayout.fixedAspect,
    this.childAspectRatio,
    this.mainAxisExtent,
    this.tileAspect,
  }) : assert(
         layout == AppAdaptiveCardGridLayout.fixedAspect || tileAspect != null,
         'masonry 布局必须提供 tileAspect',
       );

  /// GridView / MasonryGridView 的 Key(测试锚点),caller 传 'movie-summary-grid' 等。
  final Key? gridKey;

  final List<T> items;
  final bool isLoading;
  final Widget Function(BuildContext context, T item, int index) itemBuilder;
  final Widget Function(BuildContext context, int index) skeletonBuilder;

  final String? errorMessage;
  final String emptyMessage;
  final int placeholderCount;

  /// 目标列宽,列公式的 target。null → `context.appComponentTokens.movieCardTargetWidth`。
  final double? targetColumnWidth;

  final int minColumns;
  final int maxColumns;

  final AppAdaptiveCardGridLayout layout;

  /// fixedAspect 专用。null → `context.appComponentTokens.movieCardAspectRatio`。
  final double? childAspectRatio;

  /// fixedAspect 专用。提供后优先于 [childAspectRatio]，用于固定高度的横向信息卡。
  final double? mainAxisExtent;

  /// masonry 专用:每个 tile 的宽高比(通常来自 item 元数据)。
  final double Function(int index)? tileAspect;

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return _buildGrid(
        context: context,
        itemCount: placeholderCount,
        tileBuilder: (ctx, index) => skeletonBuilder(ctx, index),
      );
    }

    if (errorMessage != null) {
      return AppEmptyState(message: errorMessage!);
    }

    if (items.isEmpty) {
      return AppEmptyState(message: emptyMessage);
    }

    return _buildGrid(
      context: context,
      itemCount: items.length,
      tileBuilder: (ctx, index) => itemBuilder(ctx, items[index], index),
    );
  }

  Widget _buildGrid({
    required BuildContext context,
    required int itemCount,
    required Widget Function(BuildContext, int) tileBuilder,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final spacing = context.appSpacing.md;
        final componentTokens = context.appComponentTokens;
        final target =
            targetColumnWidth ?? componentTokens.movieCardTargetWidth;
        final columns = _resolveAppAdaptiveColumnCount(
          width: constraints.maxWidth,
          spacing: spacing,
          targetWidth: target,
          minColumns: minColumns,
          maxColumns: maxColumns,
        );

        switch (layout) {
          case AppAdaptiveCardGridLayout.fixedAspect:
            return GridView.builder(
              key: gridKey,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: itemCount,
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: columns,
                crossAxisSpacing: spacing,
                mainAxisSpacing: spacing,
                childAspectRatio:
                    childAspectRatio ?? componentTokens.movieCardAspectRatio,
                mainAxisExtent: mainAxisExtent,
              ),
              itemBuilder: tileBuilder,
            );
          case AppAdaptiveCardGridLayout.masonry:
            return MasonryGridView.count(
              key: gridKey,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: columns,
              mainAxisSpacing: spacing,
              crossAxisSpacing: spacing,
              itemCount: itemCount,
              itemBuilder:
                  (context, index) => AspectRatio(
                    aspectRatio: tileAspect!(index),
                    child: tileBuilder(context, index),
                  ),
            );
        }
      },
    );
  }
}

/// [AppAdaptiveCardGrid] 的 Sliver 版本，供累计分页页面直接放入
/// [CustomScrollView.slivers]。
///
/// 四态与非 Sliver 版本一致，但内容通过 [SliverChildBuilderDelegate] 按视口构建；
/// 固定比例使用 [SliverGrid]，瀑布流使用 [SliverMasonryGrid]。
class AppAdaptiveCardSliver<T> extends StatelessWidget {
  const AppAdaptiveCardSliver({
    super.key,
    this.gridKey,
    required this.items,
    required this.isLoading,
    required this.itemBuilder,
    required this.skeletonBuilder,
    this.errorMessage,
    this.emptyMessage = '当前没有可展示的数据。',
    this.placeholderCount = 8,
    this.targetColumnWidth,
    this.minColumns = 2,
    this.maxColumns = 6,
    this.layout = AppAdaptiveCardGridLayout.fixedAspect,
    this.childAspectRatio,
    this.mainAxisExtent,
    this.tileAspect,
  }) : assert(
         layout == AppAdaptiveCardGridLayout.fixedAspect || tileAspect != null,
         'masonry 布局必须提供 tileAspect',
       );

  final Key? gridKey;
  final List<T> items;
  final bool isLoading;
  final Widget Function(BuildContext context, T item, int index) itemBuilder;
  final Widget Function(BuildContext context, int index) skeletonBuilder;
  final String? errorMessage;
  final String emptyMessage;
  final int placeholderCount;
  final double? targetColumnWidth;
  final int minColumns;
  final int maxColumns;
  final AppAdaptiveCardGridLayout layout;
  final double? childAspectRatio;
  final double? mainAxisExtent;
  final double Function(int index)? tileAspect;

  @override
  Widget build(BuildContext context) {
    if (errorMessage != null) {
      return SliverToBoxAdapter(child: AppEmptyState(message: errorMessage!));
    }
    if (!isLoading && items.isEmpty) {
      return SliverToBoxAdapter(child: AppEmptyState(message: emptyMessage));
    }

    final itemCount = isLoading ? placeholderCount : items.length;
    return SliverLayoutBuilder(
      builder: (context, constraints) {
        final spacing = context.appSpacing.md;
        final componentTokens = context.appComponentTokens;
        final target =
            targetColumnWidth ?? componentTokens.movieCardTargetWidth;
        final columns = _resolveAppAdaptiveColumnCount(
          width: constraints.crossAxisExtent,
          spacing: spacing,
          targetWidth: target,
          minColumns: minColumns,
          maxColumns: maxColumns,
        );
        Widget buildTile(BuildContext context, int index) {
          if (isLoading) return skeletonBuilder(context, index);
          return itemBuilder(context, items[index], index);
        }

        switch (layout) {
          case AppAdaptiveCardGridLayout.fixedAspect:
            return SliverGrid(
              key: gridKey,
              delegate: SliverChildBuilderDelegate(
                buildTile,
                childCount: itemCount,
              ),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: columns,
                crossAxisSpacing: spacing,
                mainAxisSpacing: spacing,
                childAspectRatio:
                    childAspectRatio ?? componentTokens.movieCardAspectRatio,
                mainAxisExtent: mainAxisExtent,
              ),
            );
          case AppAdaptiveCardGridLayout.masonry:
            return SliverMasonryGrid.count(
              key: gridKey,
              crossAxisCount: columns,
              mainAxisSpacing: spacing,
              crossAxisSpacing: spacing,
              childCount: itemCount,
              itemBuilder:
                  (context, index) => AspectRatio(
                    aspectRatio: isLoading ? 1 : tileAspect!(index),
                    child: buildTile(context, index),
                  ),
            );
        }
      },
    );
  }
}

int _resolveAppAdaptiveColumnCount({
  required double width,
  required double spacing,
  required double targetWidth,
  required int minColumns,
  required int maxColumns,
}) {
  final columns = ((width + spacing) / (targetWidth + spacing)).floor();
  return math.max(minColumns, math.min(maxColumns, columns));
}
