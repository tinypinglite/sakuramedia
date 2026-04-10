class MovieSubtitleListDto {
  const MovieSubtitleListDto({
    required this.movieNumber,
    required this.fetchStatus,
    required this.lastAttemptedAt,
    required this.lastSucceededAt,
    required this.lastError,
    required this.items,
  });

  final String movieNumber;
  final String fetchStatus;
  final DateTime? lastAttemptedAt;
  final DateTime? lastSucceededAt;
  final String? lastError;
  final List<MovieSubtitleItemDto> items;

  factory MovieSubtitleListDto.fromJson(Map<String, dynamic> json) {
    return MovieSubtitleListDto(
      movieNumber: json['movie_number'] as String? ?? '',
      fetchStatus: json['fetch_status'] as String? ?? 'pending',
      lastAttemptedAt: _dateTimeFromJson(json['last_attempted_at']),
      lastSucceededAt: _dateTimeFromJson(json['last_succeeded_at']),
      lastError: _stringOrNull(json['last_error']),
      items: _listFromJson(
        json['items'],
        (item) => MovieSubtitleItemDto.fromJson(item),
      ),
    );
  }
}

class MovieSubtitleItemDto {
  const MovieSubtitleItemDto({
    required this.subtitleId,
    required this.fileName,
    required this.createdAt,
    required this.url,
  });

  final int subtitleId;
  final String fileName;
  final DateTime? createdAt;
  final String url;

  factory MovieSubtitleItemDto.fromJson(Map<String, dynamic> json) {
    return MovieSubtitleItemDto(
      subtitleId: json['subtitle_id'] as int? ?? 0,
      fileName: json['file_name'] as String? ?? '',
      createdAt: _dateTimeFromJson(json['created_at']),
      url: json['url'] as String? ?? '',
    );
  }
}

DateTime? _dateTimeFromJson(dynamic value) {
  if (value is! String || value.isEmpty) {
    return null;
  }
  return DateTime.tryParse(value);
}

String? _stringOrNull(dynamic value) {
  if (value is! String) {
    return null;
  }
  final trimmed = value.trim();
  if (trimmed.isEmpty) {
    return null;
  }
  return trimmed;
}

List<T> _listFromJson<T>(
  dynamic value,
  T Function(Map<String, dynamic>) fromJson,
) {
  if (value is! List) {
    return <T>[];
  }
  return value
      .whereType<Map>()
      .map(
        (item) => fromJson(
          item.map(
            (dynamic key, dynamic data) => MapEntry(key.toString(), data),
          ),
        ),
      )
      .toList(growable: false);
}
