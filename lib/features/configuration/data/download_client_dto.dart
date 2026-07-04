import 'package:sakuramedia/core/json/json_parse.dart';

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
      createdAt: asDateTime(json['created_at']),
      updatedAt: asDateTime(json['updated_at']),
    );
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

/// 连通性预检 payload。`password` 为 null 时后端会用 `clientId` 从 DB 合并原密码。
class DownloadClientProbeTestPayload {
  const DownloadClientProbeTestPayload({
    required this.baseUrl,
    required this.username,
    required this.password,
    this.clientId,
  });

  final String baseUrl;
  final String username;
  final String? password;
  final int? clientId;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'base_url': baseUrl,
      'username': username,
      'password': password,
      if (clientId != null) 'client_id': clientId,
    };
  }
}

/// 目录映射 + 硬链接预检 payload。密码处理规则同 [DownloadClientProbeTestPayload]。
class DownloadClientProbeStorageTestPayload {
  const DownloadClientProbeStorageTestPayload({
    required this.baseUrl,
    required this.username,
    required this.password,
    required this.clientSavePath,
    required this.localRootPath,
    required this.mediaLibraryId,
    this.clientId,
  });

  final String baseUrl;
  final String username;
  final String? password;
  final String clientSavePath;
  final String localRootPath;
  final int mediaLibraryId;
  final int? clientId;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'base_url': baseUrl,
      'username': username,
      'password': password,
      'client_save_path': clientSavePath,
      'local_root_path': localRootPath,
      'media_library_id': mediaLibraryId,
      if (clientId != null) 'client_id': clientId,
    };
  }
}

class DownloadClientDiagnosticErrorDto {
  const DownloadClientDiagnosticErrorDto({
    required this.type,
    required this.message,
  });

  final String type;
  final String message;

  factory DownloadClientDiagnosticErrorDto.fromJson(Map<String, dynamic> json) {
    return DownloadClientDiagnosticErrorDto(
      type: json['type'] as String? ?? '',
      message: json['message'] as String? ?? '',
    );
  }
}

class DownloadClientTestResultDto {
  const DownloadClientTestResultDto({
    required this.healthy,
    required this.checkedAt,
    required this.clientId,
    required this.clientName,
    required this.baseUrl,
    required this.elapsedMs,
    required this.version,
    required this.webApiVersion,
    required this.error,
  });

  final bool healthy;
  final DateTime? checkedAt;
  final int clientId;
  final String clientName;
  final String baseUrl;
  final int elapsedMs;
  final String? version;
  final String? webApiVersion;
  final DownloadClientDiagnosticErrorDto? error;

  factory DownloadClientTestResultDto.fromJson(Map<String, dynamic> json) {
    final errorMap = asMapOrNull(json['error']);
    return DownloadClientTestResultDto(
      healthy: json['healthy'] as bool? ?? false,
      checkedAt: asDateTime(json['checked_at']),
      clientId: asInt(json['client_id']),
      clientName: json['client_name'] as String? ?? '',
      baseUrl: json['base_url'] as String? ?? '',
      elapsedMs: asInt(json['elapsed_ms']),
      version: asStringOrNull(json['version'], trim: true),
      webApiVersion: asStringOrNull(json['web_api_version'], trim: true),
      error:
          errorMap == null
              ? null
              : DownloadClientDiagnosticErrorDto.fromJson(errorMap),
    );
  }
}

class DownloadClientStorageDirectoryMappingResultDto {
  const DownloadClientStorageDirectoryMappingResultDto({
    required this.status,
    required this.clientSavePath,
    required this.localRootPath,
    required this.probeRemoteDir,
    required this.probeLocalDir,
    required this.sentinelVisibleToQb,
    required this.error,
  });

  final String status;
  final String clientSavePath;
  final String localRootPath;
  final String probeRemoteDir;
  final String probeLocalDir;
  final bool sentinelVisibleToQb;
  final DownloadClientDiagnosticErrorDto? error;

  factory DownloadClientStorageDirectoryMappingResultDto.fromJson(
    Map<String, dynamic> json,
  ) {
    final errorMap = asMapOrNull(json['error']);
    return DownloadClientStorageDirectoryMappingResultDto(
      status: json['status'] as String? ?? '',
      clientSavePath: json['client_save_path'] as String? ?? '',
      localRootPath: json['local_root_path'] as String? ?? '',
      probeRemoteDir: json['probe_remote_dir'] as String? ?? '',
      probeLocalDir: json['probe_local_dir'] as String? ?? '',
      sentinelVisibleToQb: json['sentinel_visible_to_qb'] as bool? ?? false,
      error:
          errorMap == null
              ? null
              : DownloadClientDiagnosticErrorDto.fromJson(errorMap),
    );
  }
}

class DownloadClientStorageHardlinkResultDto {
  const DownloadClientStorageHardlinkResultDto({
    required this.status,
    required this.supported,
    required this.sourcePath,
    required this.targetPath,
    required this.error,
  });

  final String status;
  final bool supported;
  final String sourcePath;
  final String targetPath;
  final DownloadClientDiagnosticErrorDto? error;

  factory DownloadClientStorageHardlinkResultDto.fromJson(
    Map<String, dynamic> json,
  ) {
    final errorMap = asMapOrNull(json['error']);
    return DownloadClientStorageHardlinkResultDto(
      status: json['status'] as String? ?? '',
      supported: json['supported'] as bool? ?? false,
      sourcePath: json['source_path'] as String? ?? '',
      targetPath: json['target_path'] as String? ?? '',
      error:
          errorMap == null
              ? null
              : DownloadClientDiagnosticErrorDto.fromJson(errorMap),
    );
  }
}

class DownloadClientStorageTestResultDto {
  const DownloadClientStorageTestResultDto({
    required this.healthy,
    required this.checkedAt,
    required this.clientId,
    required this.clientName,
    required this.elapsedMs,
    required this.warnings,
    required this.directoryMapping,
    required this.hardlink,
  });

  final bool healthy;
  final DateTime? checkedAt;
  final int clientId;
  final String clientName;
  final int elapsedMs;
  final List<String> warnings;
  final DownloadClientStorageDirectoryMappingResultDto directoryMapping;
  final DownloadClientStorageHardlinkResultDto hardlink;

  factory DownloadClientStorageTestResultDto.fromJson(
    Map<String, dynamic> json,
  ) {
    final rawWarnings = json['warnings'];
    final warnings = rawWarnings is List
        ? rawWarnings.whereType<String>().toList(growable: false)
        : const <String>[];
    return DownloadClientStorageTestResultDto(
      healthy: json['healthy'] as bool? ?? false,
      checkedAt: asDateTime(json['checked_at']),
      clientId: asInt(json['client_id']),
      clientName: json['client_name'] as String? ?? '',
      elapsedMs: asInt(json['elapsed_ms']),
      warnings: warnings,
      directoryMapping:
          DownloadClientStorageDirectoryMappingResultDto.fromJson(
            asMap(json['directory_mapping']),
          ),
      hardlink: DownloadClientStorageHardlinkResultDto.fromJson(
        asMap(json['hardlink']),
      ),
    );
  }
}
