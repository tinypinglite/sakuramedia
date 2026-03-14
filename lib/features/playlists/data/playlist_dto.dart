class PlaylistDto {
  const PlaylistDto({
    required this.id,
    required this.name,
    required this.kind,
    required this.description,
    required this.isSystem,
    required this.isMutable,
    required this.isDeletable,
    required this.movieCount,
    required this.createdAt,
    required this.updatedAt,
  });

  final int id;
  final String name;
  final String kind;
  final String description;
  final bool isSystem;
  final bool isMutable;
  final bool isDeletable;
  final int movieCount;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  factory PlaylistDto.fromJson(Map<String, dynamic> json) {
    return PlaylistDto(
      id: json['id'] as int? ?? 0,
      name: json['name'] as String? ?? '',
      kind: json['kind'] as String? ?? 'custom',
      description: json['description'] as String? ?? '',
      isSystem: json['is_system'] as bool? ?? false,
      isMutable: json['is_mutable'] as bool? ?? false,
      isDeletable: json['is_deletable'] as bool? ?? false,
      movieCount: json['movie_count'] as int? ?? 0,
      createdAt: _dateTimeFromJson(json['created_at']),
      updatedAt: _dateTimeFromJson(json['updated_at']),
    );
  }
}

DateTime? _dateTimeFromJson(dynamic value) {
  if (value is! String || value.isEmpty) {
    return null;
  }
  return DateTime.tryParse(value);
}
