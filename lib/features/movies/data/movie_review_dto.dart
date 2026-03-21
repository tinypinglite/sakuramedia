class MovieReviewDto {
  const MovieReviewDto({
    required this.id,
    required this.score,
    required this.content,
    required this.createdAt,
    required this.username,
    required this.likeCount,
    required this.watchCount,
  });

  final int id;
  final int score;
  final String content;
  final DateTime? createdAt;
  final String username;
  final int likeCount;
  final int watchCount;

  factory MovieReviewDto.fromJson(Map<String, dynamic> json) {
    return MovieReviewDto(
      id: json['id'] as int? ?? 0,
      score: json['score'] as int? ?? 0,
      content: json['content'] as String? ?? '',
      createdAt: _dateTimeFromJson(json['created_at']),
      username: json['username'] as String? ?? '',
      likeCount: json['like_count'] as int? ?? 0,
      watchCount: json['watch_count'] as int? ?? 0,
    );
  }
}

enum MovieReviewSort {
  hotly(apiValue: 'hotly', label: '最热'),
  recently(apiValue: 'recently', label: '最新');

  const MovieReviewSort({required this.apiValue, required this.label});

  final String apiValue;
  final String label;
}

DateTime? _dateTimeFromJson(dynamic value) {
  if (value is! String || value.isEmpty) {
    return null;
  }
  return DateTime.tryParse(value);
}
