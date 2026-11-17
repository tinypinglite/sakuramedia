import 'package:json_annotation/json_annotation.dart';
import 'package:sakuramedia/core/json/dto_json_codec.dart';
import 'package:sakuramedia/core/json/json_parse.dart';

part 'download_client_dto.g.dart';

const Set<String> _defaultSupportedSourceKinds = <String>{'magnet', 'torrent'};

/// A configured download client bound to a media library.
///
/// The client implementation is owned by the library provider. The resource
/// only carries the library relation and opaque provider configuration; the
/// provider key is resolved from the referenced media library when needed.
@JsonSerializable(converters: dtoJsonConverters, createToJson: false)
class DownloadClientDto {
  const DownloadClientDto({
    required this.id,
    required this.name,
    required this.libraryId,
    this.providerConfig = const <String, dynamic>{},
    this.supportedSourceKinds = _defaultSupportedSourceKinds,
    required this.createdAt,
    required this.updatedAt,
  });

  final int id;
  final String name;
  final int libraryId;
  @JsonKey(fromJson: _unmodifiableMap)
  final Map<String, dynamic> providerConfig;

  @JsonKey(fromJson: _sourceKindsFromJson)
  final Set<String> supportedSourceKinds;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  factory DownloadClientDto.fromJson(Map<String, dynamic> json) =>
      _$DownloadClientDtoFromJson(json);
}

@JsonSerializable(createFactory: false)
class CreateDownloadClientPayload {
  const CreateDownloadClientPayload({
    required this.name,
    required this.libraryId,
    this.providerConfig = const <String, dynamic>{},
  });

  final String name;
  final int libraryId;
  final Map<String, dynamic> providerConfig;

  Map<String, dynamic> toJson() => _$CreateDownloadClientPayloadToJson(this);
}

@JsonSerializable(createFactory: false)
class UpdateDownloadClientPayload {
  const UpdateDownloadClientPayload({
    this.name,
    this.libraryId,
    this.providerConfig,
  });

  @JsonKey(includeIfNull: false)
  final String? name;

  @JsonKey(includeIfNull: false)
  final int? libraryId;

  @JsonKey(includeIfNull: false)
  final Map<String, dynamic>? providerConfig;

  Map<String, dynamic> toJson() => _$UpdateDownloadClientPayloadToJson(this);
}

@JsonSerializable(createFactory: false)
class DownloadClientTestPayload {
  const DownloadClientTestPayload({
    required this.libraryId,
    required this.providerConfig,
    this.clientId,
  });

  final int libraryId;
  final Map<String, dynamic> providerConfig;
  @JsonKey(includeIfNull: false)
  final int? clientId;

  Map<String, dynamic> toJson() => _$DownloadClientTestPayloadToJson(this);
}

@JsonSerializable(converters: dtoJsonConverters, createToJson: false)
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
  @JsonKey(fromJson: asMapOrNull)
  final Map<String, dynamic>? details;

  factory DownloadClientDiagnosticCheckDto.fromJson(
    Map<String, dynamic> json,
  ) => _$DownloadClientDiagnosticCheckDtoFromJson(json);
}

@JsonSerializable(converters: dtoJsonConverters, createToJson: false)
class DownloadClientDiagnosticReportDto {
  const DownloadClientDiagnosticReportDto({
    required this.status,
    required this.checks,
    required this.checkedAt,
    required this.elapsedMs,
  });

  final String status;
  @JsonKey(fromJson: _diagnosticChecksFromJson)
  final List<DownloadClientDiagnosticCheckDto> checks;
  final DateTime? checkedAt;
  final int elapsedMs;

  factory DownloadClientDiagnosticReportDto.fromJson(
    Map<String, dynamic> json,
  ) => _$DownloadClientDiagnosticReportDtoFromJson(json);
}

Map<String, dynamic> _unmodifiableMap(Object? value) =>
    Map<String, dynamic>.unmodifiable(asMap(value));

Set<String> _sourceKindsFromJson(Object? value) {
  if (value is! List) {
    return _defaultSupportedSourceKinds;
  }
  return Set<String>.unmodifiable(
    value
        .whereType<String>()
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty),
  );
}

List<DownloadClientDiagnosticCheckDto> _diagnosticChecksFromJson(
  Object? value,
) => asObjectList(value, DownloadClientDiagnosticCheckDto.fromJson);
