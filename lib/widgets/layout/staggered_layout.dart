import 'dart:math' as math;

import 'package:flutter/foundation.dart';

/// 瀑布流缺 width/height 时按 16:9 占位。
const double kStaggeredFallbackAspect = 16 / 9;

/// 瀑布流单个 tile 的归位结果：所在列 + 顶端 y 偏移 + tile 高度。
@immutable
class StaggeredTilePlacement {
  const StaggeredTilePlacement({
    required this.columnIndex,
    required this.topOffset,
    required this.height,
  });

  final int columnIndex;
  final double topOffset;
  final double height;

  double get bottomOffset => topOffset + height;
}

/// 瀑布流整组布局结果：每 tile 的归位 + 各列累计高度 + 单 tile 宽度。
@immutable
class StaggeredLayoutResult {
  const StaggeredLayoutResult({
    required this.tiles,
    required this.columnHeights,
    required this.tileWidth,
  });

  final List<StaggeredTilePlacement> tiles;
  final List<double> columnHeights;
  final double tileWidth;

  /// 整组瀑布流总高 = 最长列高（不含尾部 mainAxisSpacing）。
  double get totalHeight =>
      columnHeights.isEmpty
          ? 0
          : columnHeights.reduce((a, b) => a > b ? a : b);
}

/// 计算瀑布流 tile 归位：**镜像** `SliverMasonryGrid.count` 的「当前最矮列优先」放置算法
/// （并列时取最左列），缺 w/h 的 tile 回退 16:9。
///
/// 暴露成纯函数供调用方预算可视范围 / 自动滚动目标偏移用——只要算法与库一致，前端预算
/// 的 `topOffset` 就等同库实际渲染位置；库换实现的小风险由 layout 单测覆盖。
StaggeredLayoutResult computeStaggeredLayout({
  required int crossAxisCount,
  required double availableWidth,
  required double crossAxisSpacing,
  required double mainAxisSpacing,
  required List<({int? width, int? height})> items,
  double fallbackAspect = kStaggeredFallbackAspect,
}) {
  final safeColumns = math.max(0, crossAxisCount);
  if (safeColumns == 0 || items.isEmpty || availableWidth <= 0) {
    return StaggeredLayoutResult(
      tiles: const <StaggeredTilePlacement>[],
      columnHeights: List<double>.filled(safeColumns, 0, growable: false),
      tileWidth: 0,
    );
  }
  final tileWidth =
      (availableWidth - crossAxisSpacing * (safeColumns - 1)) / safeColumns;
  if (tileWidth <= 0) {
    return StaggeredLayoutResult(
      tiles: const <StaggeredTilePlacement>[],
      columnHeights: List<double>.filled(safeColumns, 0, growable: false),
      tileWidth: 0,
    );
  }
  final columnHeights = List<double>.filled(safeColumns, 0, growable: false);
  final tiles = <StaggeredTilePlacement>[];
  for (final item in items) {
    final w = item.width;
    final h = item.height;
    final aspect =
        (w != null && h != null && w > 0 && h > 0) ? w / h : fallbackAspect;
    final tileHeight = tileWidth / aspect;
    var bestColumn = 0;
    for (var c = 1; c < safeColumns; c++) {
      if (columnHeights[c] < columnHeights[bestColumn]) {
        bestColumn = c;
      }
    }
    final top = columnHeights[bestColumn];
    tiles.add(
      StaggeredTilePlacement(
        columnIndex: bestColumn,
        topOffset: top,
        height: tileHeight,
      ),
    );
    columnHeights[bestColumn] = top + tileHeight + mainAxisSpacing;
  }
  // 去掉尾部多记的 mainAxisSpacing，让 totalHeight 等于最后一行 tile 的底端。
  for (var c = 0; c < safeColumns; c++) {
    if (columnHeights[c] > 0) {
      columnHeights[c] -= mainAxisSpacing;
    }
  }
  return StaggeredLayoutResult(
    tiles: List<StaggeredTilePlacement>.unmodifiable(tiles),
    columnHeights: columnHeights,
    tileWidth: tileWidth,
  );
}
