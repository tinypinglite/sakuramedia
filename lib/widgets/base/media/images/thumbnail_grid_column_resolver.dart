import 'dart:math' as math;

int resolveThumbnailGridColumnCount({
  required double width,
  required double spacing,
  required double targetWidth,
  int minColumns = 2,
  int maxColumns = 5,
}) {
  final columns = ((width + spacing) / (targetWidth + spacing)).floor();
  return math.max(minColumns, math.min(maxColumns, columns));
}
