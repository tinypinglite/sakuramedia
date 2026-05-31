class TagListItemDto {
  const TagListItemDto({
    required this.tagId,
    required this.name,
    required this.movieCount,
  });

  final int tagId;
  final String name;
  final int movieCount;

  factory TagListItemDto.fromJson(Map<String, dynamic> json) {
    return TagListItemDto(
      tagId: json['tag_id'] as int? ?? 0,
      name: json['name'] as String? ?? '',
      movieCount: json['movie_count'] as int? ?? 0,
    );
  }
}
