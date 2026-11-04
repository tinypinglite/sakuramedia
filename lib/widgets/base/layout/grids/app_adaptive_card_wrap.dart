import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/layout/grids/grid_column_resolver.dart';

/// 自然高度卡片网格（Sliver）：按全站统一列数规格切列宽，卡片保持自身内容高度。
///
/// 用于「卡片高度由内容决定、套固定比例 cell 会在标题下方留白」的合集列表；
/// 固定比例网格仍用 `AppAdaptiveCardGrid` / `AppAdaptiveCardSliver`。列数走
/// [resolveAppCardGridColumnCount]，[orientation] 必传（合集卡为横图封面 +
/// 标题行，传 [AppCardGridOrientation.landscape]）。
///
/// 供 `CustomScrollView.slivers` 直接使用，按行拆成 [SliverList] 懒构建：合集
/// 上千时不会首帧构建全部卡片（以及全部封面图请求），行内卡片顶部对齐，行高取
/// 该行最高卡片。
class AppAdaptiveCardWrapSliver<T> extends StatelessWidget {
  const AppAdaptiveCardWrapSliver({
    super.key,
    this.gridKey,
    required this.items,
    required this.orientation,
    required this.itemBuilder,
    this.minColumns = 2,
    this.maxColumns,
    this.stretchRows = false,
  });

  /// 列表 Key（测试锚点）。
  final Key? gridKey;

  final List<T> items;
  final AppCardGridOrientation orientation;
  final Widget Function(BuildContext context, T item, int index) itemBuilder;
  final int minColumns;
  final int? maxColumns;

  /// 是否把同一行卡片拉成等高；默认保持各卡自然高度。
  final bool stretchRows;

  @override
  Widget build(BuildContext context) {
    final spacing = context.appSpacing.md;
    return SliverLayoutBuilder(
      builder: (context, constraints) {
        final columns = resolveGridColumnCount(
          width: constraints.crossAxisExtent,
          spacing: spacing,
          targetWidth: resolveAppCardGridTargetWidth(context, orientation),
          minColumns: minColumns,
          maxColumns:
              maxColumns ?? context.appComponentTokens.cardGridMaxColumns,
        );
        final cardWidth =
            (constraints.crossAxisExtent - spacing * (columns - 1)) / columns;
        final rowCount = (items.length + columns - 1) ~/ columns;
        return SliverList(
          key: gridKey,
          delegate: SliverChildBuilderDelegate((context, rowIndex) {
            final start = rowIndex * columns;
            final end = math.min(start + columns, items.length);
            final row = Row(
              crossAxisAlignment: stretchRows
                  ? CrossAxisAlignment.stretch
                  : CrossAxisAlignment.start,
              children: [
                for (var index = start; index < end; index++) ...[
                  if (index > start) SizedBox(width: spacing),
                  SizedBox(
                    width: cardWidth,
                    child: itemBuilder(context, items[index], index),
                  ),
                ],
              ],
            );
            return Padding(
              padding: EdgeInsets.only(top: rowIndex == 0 ? 0 : spacing),
              child: stretchRows ? IntrinsicHeight(child: row) : row,
            );
          }, childCount: rowCount),
        );
      },
    );
  }
}
