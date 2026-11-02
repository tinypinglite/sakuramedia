class MovieRatingValueDto {
  const MovieRatingValueDto({
    required this.dimensionId,
    required this.name,
    required this.value,
    required this.minValue,
    required this.maxValue,
  });

  final int dimensionId;
  final String name;
  final int value;
  final int minValue;
  final int maxValue;

  factory MovieRatingValueDto.fromJson(Map<String, dynamic> json) {
    return MovieRatingValueDto(
      dimensionId: json['dimension_id'] as int? ?? 0,
      name: json['name'] as String? ?? '',
      value: json['value'] as int? ?? 0,
      minValue: json['min_value'] as int? ?? 1,
      maxValue: json['max_value'] as int? ?? 5,
    );
  }
}

class MovieRatingDto {
  const MovieRatingDto({
    required this.movieNumber,
    required this.rated,
    this.totalScore,
    this.values = const <MovieRatingValueDto>[],
    this.updatedAt,
  });

  final String movieNumber;
  final bool rated;

  /// 总分固定 1-5，保留一位小数。
  final double? totalScore;
  final List<MovieRatingValueDto> values;
  final DateTime? updatedAt;

  factory MovieRatingDto.fromJson(Map<String, dynamic> json) {
    final rawValues = json['values'];
    return MovieRatingDto(
      movieNumber: json['movie_number'] as String? ?? '',
      rated: json['rated'] as bool? ?? false,
      totalScore: (json['total_score'] as num?)?.toDouble(),
      values: rawValues is List
          ? rawValues
                .whereType<Map<String, dynamic>>()
                .map(MovieRatingValueDto.fromJson)
                .toList(growable: false)
          : const <MovieRatingValueDto>[],
      updatedAt: DateTime.tryParse(json['updated_at'] as String? ?? ''),
    );
  }
}
