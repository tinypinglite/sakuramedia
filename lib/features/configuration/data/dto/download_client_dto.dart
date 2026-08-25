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
