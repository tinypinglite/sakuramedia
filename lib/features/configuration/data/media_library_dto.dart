class MediaLibraryDto {
  const MediaLibraryDto({
    required this.id,
    required this.name,
    required this.rootPath,
    required this.createdAt,
    required this.updatedAt,
  });

  final int id;
  final String name;
  final String rootPath;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  factory MediaLibraryDto.fromJson(Map<String, dynamic> json) {
    return MediaLibraryDto(
      id: json['id'] as int? ?? 0,
      name: json['name'] as String? ?? '',
      rootPath: json['root_path'] as String? ?? '',
      createdAt: _parseDateTime(json['created_at']),
      updatedAt: _parseDateTime(json['updated_at']),
    );
  }

  static DateTime? _parseDateTime(dynamic value) {
    if (value is! String || value.isEmpty) {
      return null;
    }
    return DateTime.tryParse(value);
  }
}

class CreateMediaLibraryPayload {
  const CreateMediaLibraryPayload({required this.name, required this.rootPath});

  final String name;
  final String rootPath;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{'name': name, 'root_path': rootPath};
  }
}

class UpdateMediaLibraryPayload {
  const UpdateMediaLibraryPayload({this.name, this.rootPath});

  final String? name;
  final String? rootPath;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      if (name != null) 'name': name,
      if (rootPath != null) 'root_path': rootPath,
    };
  }
}
