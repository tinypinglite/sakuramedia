import 'package:sakuramedia/features/shared/data/movie_interaction_filter.dart';

class MovieInteractionDistributionDto {
  const MovieInteractionDistributionDto({this.p999, this.max});

  final num? p999;
  final num? max;

  factory MovieInteractionDistributionDto.fromJson(Object? value) {
    if (value is! Map) {
      return const MovieInteractionDistributionDto();
    }
    final json = value.map(
      (dynamic key, dynamic data) => MapEntry(key.toString(), data),
    );
    return MovieInteractionDistributionDto(
      p999: json['p999'] as num?,
      max: json['max'] as num?,
    );
  }
}

class MovieInteractionFilterOptionsDto {
  const MovieInteractionFilterOptionsDto({
    required this.movieCount,
    required this.heat,
    this.heatVersion,
  });

  final int movieCount;
  final MovieInteractionDistributionDto heat;
  final String? heatVersion;

  factory MovieInteractionFilterOptionsDto.fromJson(Map<String, dynamic> json) {
    return MovieInteractionFilterOptionsDto(
      movieCount: json['movie_count'] as int? ?? 0,
      heat: MovieInteractionDistributionDto.fromJson(json['heat']),
      heatVersion: json['heat_version'] as String?,
    );
  }

  /// 热度滑块上限：优先 P99.9，缺失时退回 MAX。
  num? sliderMaxFor(MovieInteractionMetric metric) {
    final distribution = switch (metric) {
      MovieInteractionMetric.heat => heat,
    };
    final candidate = _positive(distribution.p999) ?? distribution.max;
    return _positive(candidate);
  }

  static num? _positive(num? value) =>
      value != null && value > 0 ? value : null;
}
