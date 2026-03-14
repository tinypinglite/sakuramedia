class DownloadClientDto {
  const DownloadClientDto({
    required this.id,
    required this.name,
    required this.baseUrl,
    required this.username,
    required this.clientSavePath,
    required this.localRootPath,
    required this.mediaLibraryId,
    required this.hasPassword,
    required this.createdAt,
    required this.updatedAt,
  });

  final int id;
  final String name;
  final String baseUrl;
  final String username;
  final String clientSavePath;
  final String localRootPath;
  final int mediaLibraryId;
  final bool hasPassword;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  factory DownloadClientDto.fromJson(Map<String, dynamic> json) {
    return DownloadClientDto(
      id: json['id'] as int? ?? 0,
      name: json['name'] as String? ?? '',
      baseUrl: json['base_url'] as String? ?? '',
      username: json['username'] as String? ?? '',
      clientSavePath: json['client_save_path'] as String? ?? '',
      localRootPath: json['local_root_path'] as String? ?? '',
      mediaLibraryId: json['media_library_id'] as int? ?? 0,
      hasPassword: json['has_password'] as bool? ?? false,
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

class CreateDownloadClientPayload {
  const CreateDownloadClientPayload({
    required this.name,
    required this.baseUrl,
    required this.username,
    required this.password,
    required this.clientSavePath,
    required this.localRootPath,
    required this.mediaLibraryId,
  });

  final String name;
  final String baseUrl;
  final String username;
  final String password;
  final String clientSavePath;
  final String localRootPath;
  final int mediaLibraryId;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'name': name,
      'base_url': baseUrl,
      'username': username,
      'password': password,
      'client_save_path': clientSavePath,
      'local_root_path': localRootPath,
      'media_library_id': mediaLibraryId,
    };
  }
}

class UpdateDownloadClientPayload {
  const UpdateDownloadClientPayload({
    this.name,
    this.baseUrl,
    this.username,
    this.password,
    this.clientSavePath,
    this.localRootPath,
    this.mediaLibraryId,
  });

  final String? name;
  final String? baseUrl;
  final String? username;
  final String? password;
  final String? clientSavePath;
  final String? localRootPath;
  final int? mediaLibraryId;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      if (name != null) 'name': name,
      if (baseUrl != null) 'base_url': baseUrl,
      if (username != null) 'username': username,
      if (password != null) 'password': password,
      if (clientSavePath != null) 'client_save_path': clientSavePath,
      if (localRootPath != null) 'local_root_path': localRootPath,
      if (mediaLibraryId != null) 'media_library_id': mediaLibraryId,
    };
  }
}
