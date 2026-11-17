import 'package:flutter/foundation.dart' show immutable, mapEquals;
import 'package:sakuramedia/l10n/app_localizations.dart';

/// 影片互动数筛选项。字段与后端 `*_min` / `*_max` query 参数一一对应。
enum MovieInteractionMetric {
  heat('heat');

  const MovieInteractionMetric(this.apiValue, {this.isDecimal = false});

  final String apiValue;

  final bool isDecimal;

  /// 互动数字段的展示文案，按当前语言渲染。
  String localizedLabel(AppLocalizations l10n) => switch (this) {
    MovieInteractionMetric.heat => l10n.sharedInteractionHeat,
  };

  String format(num value) => isDecimal
      ? value.toDouble().toStringAsFixed(1)
      : value.round().toString();

  /// 滑块两端刻度：万级用 `w`，其余直接显示整数。
  String sliderMaxLabel(double maxValue) {
    if (isDecimal) {
      return maxValue == maxValue.roundToDouble()
          ? maxValue.toStringAsFixed(0)
          : maxValue.toStringAsFixed(1);
    }
    if (maxValue >= 10000) {
      final text = (maxValue / 10000).toStringAsFixed(1);
      return '${text.endsWith('.0') ? text.substring(0, text.length - 2) : text}w';
    }
    return maxValue.round().toString();
  }

  num normalize(double value) =>
      isDecimal ? (value * 10).round() / 10 : value.round();

  num? minFromSlider(double value) => value <= 0 ? null : normalize(value);

  num? maxFromSlider(double value, double maxValue) =>
      value >= maxValue ? null : normalize(value);
}

@immutable
class MovieInteractionRange {
  const MovieInteractionRange({this.min, this.max});

  final num? min;
  final num? max;

  bool get isEmpty => min == null && max == null;

  bool matches(MovieInteractionRange other) =>
      min == other.min && max == other.max;

  @override
  bool operator ==(Object other) =>
      other is MovieInteractionRange && matches(other);

  @override
  int get hashCode => Object.hash(min, max);
}

/// 影片互动数范围条件集合；影片库和排行榜共用。
@immutable
class MovieInteractionFilter {
  const MovieInteractionFilter({
    this.ranges = const <MovieInteractionMetric, MovieInteractionRange>{},
  });

  final Map<MovieInteractionMetric, MovieInteractionRange> ranges;

  static const MovieInteractionFilter initial = MovieInteractionFilter();

  MovieInteractionRange? rangeFor(MovieInteractionMetric metric) =>
      ranges[metric];

  bool get isDefault => ranges.isEmpty;

  int get activeMetricCount => ranges.length;

  MovieInteractionFilter withRange(
    MovieInteractionMetric metric, {
    num? min,
    num? max,
  }) {
    final next = Map<MovieInteractionMetric, MovieInteractionRange>.of(ranges);
    if (min == null && max == null) {
      next.remove(metric);
    } else {
      next[metric] = MovieInteractionRange(min: min, max: max);
    }
    return MovieInteractionFilter(ranges: Map.unmodifiable(next));
  }

  MovieInteractionFilter clear() => initial;

  bool matches(MovieInteractionFilter other) => mapEquals(ranges, other.ranges);

  void addQueryParameters(Map<String, dynamic> parameters) {
    for (final entry in ranges.entries) {
      final metric = entry.key;
      final range = entry.value;
      if (range.min != null) {
        parameters['${metric.apiValue}_min'] = range.min;
      }
      if (range.max != null) {
        parameters['${metric.apiValue}_max'] = range.max;
      }
    }
  }

  /// 互动数筛选摘要，按当前语言渲染。
  String localizedSummaryLabel(AppLocalizations l10n) {
    if (ranges.isEmpty) {
      return '';
    }
    if (ranges.length == 1) {
      final metric = MovieInteractionMetric.values.firstWhere(
        ranges.containsKey,
      );
      return '${metric.localizedLabel(l10n)} '
          '${movieInteractionRangeLabel(metric, ranges[metric]!.min, ranges[metric]!.max, l10n)}';
    }
    return l10n.sharedInteractionSummary(activeMetricCount);
  }
}

/// 单个互动数字段的展示文案，筛选面板与入口摘要共用。
String movieInteractionRangeLabel(
  MovieInteractionMetric metric,
  num? min,
  num? max,
  AppLocalizations l10n,
) {
  if (min != null && max != null) {
    return '${metric.format(min)} ~ ${metric.format(max)}';
  }
  if (min != null) {
    return '≥ ${metric.format(min)}';
  }
  if (max != null) {
    return '≤ ${metric.format(max)}';
  }
  return l10n.sharedInteractionUnlimited;
}
