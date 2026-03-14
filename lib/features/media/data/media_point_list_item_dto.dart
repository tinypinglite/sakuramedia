class MediaPointListItemDto {
  const MediaPointListItemDto({
    required this.pointId,
    required this.mediaId,
    required this.movieNumber,
    required this.offsetSeconds,
    required this.createdAt,
  });

  final int pointId;
  final int mediaId;
  final String movieNumber;
  final int offsetSeconds;
  final DateTime? createdAt;

  factory MediaPointListItemDto.fromJson(Map<String, dynamic> json) {
    return MediaPointListItemDto(
      pointId: json['point_id'] as int? ?? 0,
      mediaId: json['media_id'] as int? ?? 0,
      movieNumber: json['movie_number'] as String? ?? '',
      offsetSeconds: json['offset_seconds'] as int? ?? 0,
      createdAt: _dateTimeFromJson(json['created_at']),
    );
  }
}

DateTime? _dateTimeFromJson(dynamic value) {
  final raw = value as String?;
  if (raw == null || raw.isEmpty) {
    return null;
  }
  return DateTime.tryParse(raw);
}
