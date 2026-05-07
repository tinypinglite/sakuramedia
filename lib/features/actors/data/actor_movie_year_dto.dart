class ActorMovieYearDto {
  const ActorMovieYearDto({required this.year, required this.movieCount});

  final int year;
  final int movieCount;

  factory ActorMovieYearDto.fromJson(Map<String, dynamic> json) {
    return ActorMovieYearDto(
      year: json['year'] as int? ?? 0,
      movieCount: json['movie_count'] as int? ?? 0,
    );
  }
}
