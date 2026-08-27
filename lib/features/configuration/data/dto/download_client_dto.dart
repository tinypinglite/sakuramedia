import 'package:sakuramedia/core/json/json_parse.dart';

/// A configured download client bound to a media library.
///
/// The client implementation is owned by the library provider. The resource
/// only carries the library relation and opaque provider configuration; the
/// provider key is resolved from the referenced media library when needed.
class DownloadClientDto {
  const DownloadClientDto({
    required this.id,
    required this.name,
    required this.libraryId,
    this.providerConfig = const <String, dynamic>{},
    required this.createdAt,
    required this.updatedAt,
  });

  final int id;
  final String name;
  final int libraryId;
  final Map<String, dynamic> providerConfig;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  factory DownloadClientDto.fromJson(Map<String, dynamic> json) {
    final rawConfig = json['provider_config'];
    final config = rawConfig is Map
        ? rawConfig.map(
            (dynamic key, dynamic value) => MapEntry(key.toString(), value),
          )
        : <String, dynamic>{};
    return DownloadClientDto(
      id: json['id'] as int? ?? 0,
      name: json['name'] as String? ?? '',
      libraryId: json['library_id'] as int? ?? 0,
      providerConfig: Map<String, dynamic>.unmodifiable(config),
      createdAt: asDateTime(json['created_at']),
      updatedAt: asDateTime(json['updated_at']),
    );
  }
}

class CreateDownloadClientPayload {
  const CreateDownloadClientPayload({
    required this.name,
    required this.libraryId,
    this.providerConfig = const <String, dynamic>{},
  });

  final String name;
  final int libraryId;
  final Map<String, dynamic> providerConfig;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'name': name,
      'library_id': libraryId,
      'provider_config': providerConfig,
    };
  }
}

class UpdateDownloadClientPayload {
  const UpdateDownloadClientPayload({
    this.name,
    this.libraryId,
    this.providerConfig,
  });

  final String? name;
  final int? libraryId;
  final Map<String, dynamic>? providerConfig;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      if (name != null) 'name': name,
      if (libraryId != null) 'library_id': libraryId,
      if (providerConfig != null) 'provider_config': providerConfig,
    };
  }
}

class DownloadClientTestPayload {
  const DownloadClientTestPayload({
    required this.libraryId,
    required this.providerConfig,
    this.clientId,
  });

  final int libraryId;
  final Map<String, dynamic> providerConfig;
  final int? clientId;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'library_id': libraryId,
      'provider_config': providerConfig,
      if (clientId != null) 'client_id': clientId,
    };
  }
}

class DownloadClientDiagnosticCheckDto {
  const DownloadClientDiagnosticCheckDto({
    required this.key,
    required this.status,
    required this.code,
    required this.message,
    this.details,
  });

  final String key;
  final String status;
  final String code;
  final String message;
  final Map<String, dynamic>? details;

  factory DownloadClientDiagnosticCheckDto.fromJson(
    Map<String, dynamic> json,
  ) {
    return DownloadClientDiagnosticCheckDto(
      key: json['key'] as String? ?? '',
      status: json['status'] as String? ?? 'failed',
      code: json['code'] as String? ?? '',
      message: json['message'] as String? ?? '',
      details: asMapOrNull(json['details']),
    );
  }
}

class DownloadClientDiagnosticReportDto {
  const DownloadClientDiagnosticReportDto({
    required this.status,
    required this.checks,
    required this.checkedAt,
    required this.elapsedMs,
  });

  final String status;
  final List<DownloadClientDiagnosticCheckDto> checks;
  final DateTime? checkedAt;
  final int elapsedMs;

  factory DownloadClientDiagnosticReportDto.fromJson(
    Map<String, dynamic> json,
  ) {
    final rawChecks = json['checks'];
    final checks = rawChecks is List
        ? rawChecks
              .whereType<Map>()
              .map(
                (item) => DownloadClientDiagnosticCheckDto.fromJson(
                  Map<String, dynamic>.from(item),
                ),
              )
              .toList(growable: false)
        : const <DownloadClientDiagnosticCheckDto>[];
    return DownloadClientDiagnosticReportDto(
      status: json['status'] as String? ?? 'failed',
      checks: checks,
      checkedAt: asDateTime(json['checked_at']),
      elapsedMs: asInt(json['elapsed_ms']),
    );
  }
}
