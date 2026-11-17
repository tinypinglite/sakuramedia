class ParsedMovieNumberDto {
  const ParsedMovieNumberDto({
    required this.query,
    required this.parsed,
    required this.movieNumber,
    required this.reason,
  });

  final String query;
  final bool parsed;
  final String? movieNumber;
  final String? reason;

  factory ParsedMovieNumberDto.fromJson(Map<String, dynamic> json) {
    return ParsedMovieNumberDto(
      query: json['query'] as String? ?? '',
      parsed: json['parsed'] as bool? ?? false,
      movieNumber: json['movie_number'] as String?,
      reason: json['reason'] as String?,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is ParsedMovieNumberDto &&
        other.query == query &&
        other.parsed == parsed &&
        other.movieNumber == movieNumber &&
        other.reason == reason;
  }

  @override
  int get hashCode => Object.hash(query, parsed, movieNumber, reason);
}
