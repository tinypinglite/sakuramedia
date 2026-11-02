class RatingDimensionDto {
  const RatingDimensionDto({
    required this.id,
    required this.name,
    required this.minValue,
    required this.maxValue,
    this.weight = 1,
    this.hasScores = false,
  });

  final int id;
  final String name;
  final int minValue;
  final int maxValue;

  /// 初版界面不开放权重编辑，保留字段以便与后端约定一致。
  final double weight;
  final bool hasScores;

  factory RatingDimensionDto.fromJson(Map<String, dynamic> json) {
    return RatingDimensionDto(
      id: json['id'] as int? ?? 0,
      name: json['name'] as String? ?? '',
      minValue: json['min_value'] as int? ?? 1,
      maxValue: json['max_value'] as int? ?? 5,
      weight: (json['weight'] as num?)?.toDouble() ?? 1,
      hasScores: json['has_scores'] as bool? ?? false,
    );
  }
}
