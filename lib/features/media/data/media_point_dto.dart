class MediaPointDto {
  const MediaPointDto({
    required this.pointId,
    required this.mediaId,
    required this.offsetSeconds,
    required this.createdAt,
  });

  final int pointId;
  final int mediaId;
  final int offsetSeconds;
  final DateTime? createdAt;

  factory MediaPointDto.fromJson(Map<String, dynamic> json) {
    return MediaPointDto(
      pointId: json['point_id'] as int? ?? 0,
      mediaId: json['media_id'] as int? ?? 0,
      offsetSeconds: json['offset_seconds'] as int? ?? 0,
      createdAt: _dateTimeFromJson(json['created_at']),
    );
  }

  static DateTime? _dateTimeFromJson(dynamic value) {
    if (value is! String || value.isEmpty) {
      return null;
    }
    return DateTime.tryParse(value);
  }
}
