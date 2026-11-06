import 'package:material_ui/material_ui.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/feedback/app_empty_state.dart';
import 'package:sakuramedia/widgets/base/l10n/app_l10n.dart';
import 'package:sakuramedia/widgets/base/layout/grids/app_sliver_width_builder.dart';
import 'package:sakuramedia/widgets/base/layout/grids/grid_column_resolver.dart';

/// 布局模式：等宽 tile(固定 aspect ratio) vs 瀑布流(逐 tile aspect)。
enum AppAdaptiveCardGridLayout { fixedAspect, masonry }

/// 自适应三态卡片网格：**错误 → 空态 → 内容**。
///
/// 消除 movies / actors / rankings / videos 四份网格的 copy-paste:
/// - 列数按 `((width + spacing) / (targetWidth + spacing)).floor()` 计算,
///   钳位到 [minColumns, maxColumns]；目标列宽按 [orientation] 取全站统一规格
///   [AppComponentTokens.cardGridPortraitTargetWidth] /
///   [AppComponentTokens.cardGridMixedTargetWidth] /
///   [AppComponentTokens.cardGridLandscapeTargetWidth]，列数上限取
///   [AppComponentTokens.cardGridMaxColumns]；
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
    this.emptyMessage,
    this.targetColumnWidth,
    this.orientation,
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

  /// GridView / MasonryGridView 的 Key(测试锚点),caller 传 'movie-summary-grid' 等。
  final Key? gridKey;

  final List<T> items;
  final Widget Function(BuildContext context, T item, int index) itemBuilder;

  final String? errorMessage;
  final String? emptyMessage;

  /// 目标列宽,列公式的 target。null → 按 [orientation] 取统一 token。
  final double? targetColumnWidth;

  /// 卡片朝向档位，决定目标列宽取哪一档 token。
  ///
  /// null → 按布局自动推导：fixedAspect 用 [childAspectRatio]（缺省按
  /// [AppComponentTokens.movieCardAspectRatio]）判断，比例 >= 1 视为横图，
  /// 否则竖图；masonry 和仅设置 [mainAxisExtent] 的卡片取
  /// [AppCardGridOrientation.mixed]。[targetColumnWidth] 优先于本参数。
  final AppCardGridOrientation? orientation;

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

  @override
  Widget build(BuildContext context) {
    if (errorMessage != null) {
      return AppEmptyState(message: errorMessage!);
    }

    if (items.isEmpty) {
      return AppEmptyState(
        message: emptyMessage ?? appL10n(context).baseEmptyData,
      );
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
            targetColumnWidth ??
            resolveAppCardGridTargetWidth(
              context,
              resolveAppCardGridOrientation(
                layout: layout,
                orientation: orientation,
                childAspectRatio: childAspectRatio,
                mainAxisExtent: mainAxisExtent,
                tokens: componentTokens,
              ),
            );
        final columns = resolveGridColumnCount(
          width: constraints.maxWidth,
          spacing: spacing,
          targetWidth: target,
          minColumns: minColumns,
          maxColumns: maxColumns ?? componentTokens.cardGridMaxColumns,
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
              itemBuilder: (context, index) => AspectRatio(
                aspectRatio: tileAspect!(index),
                child: tileBuilder(context, index),
              ),
            );
        }
      },
    );
  }
}

/// 未显式声明朝向时按布局信号推导目标列宽档位。
///
/// fixedAspect 用宽高比：`>= 1` 视为横图，缺省比例按
/// [AppComponentTokens.movieCardAspectRatio]；masonry 逐项比例由数据决定，
/// 仅设置 [AppAdaptiveCardGrid.mainAxisExtent] 的卡片没有比例信号，两者都取
/// [AppCardGridOrientation.mixed]。
AppCardGridOrientation resolveAppCardGridOrientation({
  required AppAdaptiveCardGridLayout layout,
  required AppCardGridOrientation? orientation,
  required double? childAspectRatio,
  required double? mainAxisExtent,
  required AppComponentTokens tokens,
}) {
  if (orientation case final explicit?) {
    return explicit;
  }
  if (layout == AppAdaptiveCardGridLayout.masonry) {
    return AppCardGridOrientation.mixed;
  }
  if (childAspectRatio == null && mainAxisExtent != null) {
    return AppCardGridOrientation.mixed;
  }
  final aspectRatio = childAspectRatio ?? tokens.movieCardAspectRatio;
  return aspectRatio >= 1
      ? AppCardGridOrientation.landscape
      : AppCardGridOrientation.portrait;
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
    this.emptyMessage,
    this.targetColumnWidth,
    this.orientation,
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
  final String? emptyMessage;

  /// 目标列宽,列公式的 target。null → 按 [orientation] 取统一 token。
  final double? targetColumnWidth;

  /// 卡片朝向档位，语义同 [AppAdaptiveCardGrid.orientation]。
  final AppCardGridOrientation? orientation;

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
      return SliverToBoxAdapter(
        child: AppEmptyState(
          message: emptyMessage ?? appL10n(context).baseEmptyData,
        ),
      );
    }

    final itemCount = items.length;
    final spacing = context.appSpacing.md;
    final componentTokens = context.appComponentTokens;
    final target =
        targetColumnWidth ??
        resolveAppCardGridTargetWidth(
          context,
          resolveAppCardGridOrientation(
            layout: layout,
            orientation: orientation,
            childAspectRatio: childAspectRatio,
            mainAxisExtent: mainAxisExtent,
            tokens: componentTokens,
          ),
        );
    final resolvedMaxColumns = maxColumns ?? componentTokens.cardGridMaxColumns;
    return AppSliverWidthBuilder(
      builder: (context, width) {
        final columns = resolveGridColumnCount(
          width: width,
          spacing: spacing,
          targetWidth: target,
          minColumns: minColumns,
          maxColumns: resolvedMaxColumns,
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
                // 网格 tile 均未申请 keep-alive；AutomaticKeepAlive 只增加元素开销。
                addAutomaticKeepAlives: false,
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
              itemBuilder: (context, index) => AspectRatio(
                aspectRatio: tileAspect!(index),
                child: buildTile(context, index),
              ),
            );
        }
      },
    );
  }
}
