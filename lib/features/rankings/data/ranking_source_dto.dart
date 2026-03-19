class RankingSourceDto {
  const RankingSourceDto({required this.sourceKey, required this.name});

  final String sourceKey;
  final String name;

  factory RankingSourceDto.fromJson(Map<String, dynamic> json) {
    return RankingSourceDto(
      sourceKey: json['source_key'] as String? ?? '',
      name: json['name'] as String? ?? '',
    );
  }
}
