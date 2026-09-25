import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/theme.dart';

/// 网格列数公式：按目标列宽算出能容纳的列数，并夹在 `[minColumns, maxColumns]`。
///
/// 缩略图面板、切片 / 视频 / 时刻合集详情的网格都用同一套公式，差别只在
/// `targetWidth` 与列数上限；本函数是唯一实现，避免每页各抄一份魔数。
///
/// 卡片列表页、合集列表和合集详情请改用 [resolveAppCardGridColumnCount]，
/// 让目标列宽和列数上限统一从 token 取值。
int resolveGridColumnCount({
  required double width,
  required double spacing,
  required double targetWidth,
  int minColumns = 2,
  int maxColumns = 5,
}) {
  final columns = ((width + spacing) / (targetWidth + spacing)).floor();
  return math.max(minColumns, math.min(maxColumns, columns));
}

/// 全站卡片网格的统一列数入口。
///
/// 目标列宽与列数上限读 [AppComponentTokens.cardGridTargetWidth] /
/// [AppComponentTokens.cardGridMaxColumns]：调整卡片密度只改 token，一处生效。
/// 手写 [GridView] / [SliverGrid] 的页面走本函数，其余优先用
/// `AppAdaptiveCardGrid` / `AppAdaptiveCardSliver`（内部走同一套规格）。
int resolveAppCardGridColumnCount(
  BuildContext context, {
  required double width,
  required double spacing,
}) {
  final tokens = context.appComponentTokens;
  return resolveGridColumnCount(
    width: width,
    spacing: spacing,
    targetWidth: tokens.cardGridTargetWidth,
    maxColumns: tokens.cardGridMaxColumns,
  );
}
