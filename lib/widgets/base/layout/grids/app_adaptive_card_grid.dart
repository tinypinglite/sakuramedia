import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/feedback/app_empty_state.dart';
import 'package:sakuramedia/widgets/base/layout/grids/grid_column_resolver.dart';

/// 布局模式：等宽 tile(固定 aspect ratio) vs 瀑布流(逐 tile aspect)。
enum AppAdaptiveCardGridLayout { fixedAspect, masonry }

/// 自适应三态卡片网格：**错误 → 空态 → 内容**。
///
/// 消除 movies / actors / rankings / videos 四份网格的 copy-paste:
/// - 列数按 `((width + spacing) / (targetWidth + spacing)).floor()` 计算,
///   钳位到 [minColumns, maxColumns]；目标列宽与列数上限默认取全站统一规格
///   [AppComponentTokens.cardGridTargetWidth] / [AppComponentTokens.cardGridMaxColumns]；
/// - `layout: fixedAspect` 走 [GridView] + [childAspectRatio]；
/// - `layout: masonry` 走 [MasonryGridView] + [tileAspect]（每 tile 自算高度）。
///
/// 首屏加载由 caller 用占位数据渲染真实卡片并外包 `AppSkeletonizer`，
/// 内容 tile 走 [itemBuilder]，泛型 [T] 由 caller 决定。
///
/// 本组件只适合固定少量、嵌入其它滚动区的预览内容。累计分页页面必须使用
/// [AppAdaptiveCardSliver]，否则 `shrinkWrap` 会为计算完整高度而布局全部条目。
class AppAdaptiveCardGrid<T> extends StatelessWidget {
  const AppAdaptiveCardGrid({
    super.key,
    this.gridKey,
    required this.items,
    required this.itemBuilder,
    this.errorMessage,
    this.emptyMessage = '当前没有可展示的数据。',
    this.targetColumnWidth,
    this.minColumns = 2,
    this.maxColumns,
    this.layout = AppAdaptiveCardGridLayout.fixedAspect,
    this.childAspectRatio,
    this.mainAxisExtent,
    this.tileAspect,
    this.maxRows,
  }) : assert(
         layout == AppAdaptiveCardGridLayout.fixedAspect || tileAspect != null,
         'masonry 布局必须提供 tileAspect',
       ),
       assert(maxRows == null || maxRows > 0, 'maxRows 必须大于 0');

  /// GridView / MasonryGridView 的 Key(测试锚点),caller 传 'movie-summary-grid' 等。
  final Key? gridKey;

  final List<T> items;
  final Widget Function(BuildContext context, T item, int index) itemBuilder;

  final String? errorMessage;
  final String emptyMessage;

  /// 目标列宽,列公式的 target。null → [AppComponentTokens.cardGridTargetWidth]。
  final double? targetColumnWidth;

  final int minColumns;

  /// 列数上限。null → [AppComponentTokens.cardGridMaxColumns]。
  final int? maxColumns;

  final AppAdaptiveCardGridLayout layout;

  /// fixedAspect 专用。null → `context.appComponentTokens.movieCardAspectRatio`。
  final double? childAspectRatio;

  /// fixedAspect 专用。提供后优先于 [childAspectRatio]，用于固定高度的横向信息卡。
  final double? mainAxisExtent;

  /// masonry 专用:每个 tile 的宽高比(通常来自 item 元数据)。
  final double Function(int index)? tileAspect;

  /// 限制可见行数。用于首页预览等「只展示一行，更多内容进入详情页」的场景。
  ///
  /// 保持为空时展示全部 [items]，与既有列表行为一致。
  final int? maxRows;

  @override
  Widget build(BuildContext context) {
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
            targetColumnWidth ?? componentTokens.cardGridTargetWidth;
        final columns = resolveGridColumnCount(
          width: constraints.maxWidth,
          spacing: spacing,
          targetWidth: target,
          minColumns: minColumns,
          maxColumns: maxColumns ?? componentTokens.cardGridMaxColumns,
        );
        final visibleItemCount =
            maxRows == null ? itemCount : math.min(itemCount, columns * maxRows!);

        switch (layout) {
          case AppAdaptiveCardGridLayout.fixedAspect:
            return GridView.builder(
              key: gridKey,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: visibleItemCount,
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
              itemCount: visibleItemCount,
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
/// 三态与非 Sliver 版本一致，但内容通过 [SliverChildBuilderDelegate] 按视口构建；
/// 固定比例使用 [SliverGrid]，瀑布流使用 [SliverMasonryGrid]。
class AppAdaptiveCardSliver<T> extends StatelessWidget {
  const AppAdaptiveCardSliver({
    super.key,
    this.gridKey,
    required this.items,
    required this.itemBuilder,
    this.errorMessage,
    this.emptyMessage = '当前没有可展示的数据。',
    this.targetColumnWidth,
    this.minColumns = 2,
    this.maxColumns,
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
  final Widget Function(BuildContext context, T item, int index) itemBuilder;
  final String? errorMessage;
  final String emptyMessage;
  final double? targetColumnWidth;
  final int minColumns;
  final int? maxColumns;
  final AppAdaptiveCardGridLayout layout;
  final double? childAspectRatio;
  final double? mainAxisExtent;
  final double Function(int index)? tileAspect;

  @override
  Widget build(BuildContext context) {
    if (errorMessage != null) {
      return SliverToBoxAdapter(child: AppEmptyState(message: errorMessage!));
    }
    if (items.isEmpty) {
      return SliverToBoxAdapter(child: AppEmptyState(message: emptyMessage));
    }

    final itemCount = items.length;
    return SliverLayoutBuilder(
      builder: (context, constraints) {
        final spacing = context.appSpacing.md;
        final componentTokens = context.appComponentTokens;
        final target =
            targetColumnWidth ?? componentTokens.cardGridTargetWidth;
        final columns = resolveGridColumnCount(
          width: constraints.crossAxisExtent,
          spacing: spacing,
          targetWidth: target,
          minColumns: minColumns,
          maxColumns: maxColumns ?? componentTokens.cardGridMaxColumns,
        );
        Widget buildTile(BuildContext context, int index) {
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
                    aspectRatio: tileAspect!(index),
                    child: buildTile(context, index),
                  ),
            );
        }
      },
    );
  }
}
