// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'download_client_dto.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

DownloadClientDto _$DownloadClientDtoFromJson(Map<String, dynamic> json) =>
    DownloadClientDto(
      id: const IntJsonConverter().fromJson(json['id']),
      name: const StringJsonConverter().fromJson(json['name']),
      libraryId: const IntJsonConverter().fromJson(json['library_id']),
      providerConfig: json['provider_config'] == null
          ? const <String, dynamic>{}
          : _unmodifiableMap(json['provider_config']),
      supportedSourceKinds: json['supported_source_kinds'] == null
          ? _defaultSupportedSourceKinds
          : _sourceKindsFromJson(json['supported_source_kinds']),
      createdAt: const DateTimeJsonConverter().fromJson(json['created_at']),
      updatedAt: const DateTimeJsonConverter().fromJson(json['updated_at']),
    );

Map<String, dynamic> _$CreateDownloadClientPayloadToJson(
  CreateDownloadClientPayload instance,
) => <String, dynamic>{
  'name': instance.name,
  'library_id': instance.libraryId,
  'provider_config': instance.providerConfig,
};

Map<String, dynamic> _$UpdateDownloadClientPayloadToJson(
  UpdateDownloadClientPayload instance,
) => <String, dynamic>{
  'name': ?instance.name,
  'library_id': ?instance.libraryId,
  'provider_config': ?instance.providerConfig,
};

Map<String, dynamic> _$DownloadClientTestPayloadToJson(
  DownloadClientTestPayload instance,
) => <String, dynamic>{
  'library_id': instance.libraryId,
  'provider_config': instance.providerConfig,
  'client_id': ?instance.clientId,
};

DownloadClientDiagnosticCheckDto _$DownloadClientDiagnosticCheckDtoFromJson(
  Map<String, dynamic> json,
) => DownloadClientDiagnosticCheckDto(
  key: const StringJsonConverter().fromJson(json['key']),
  status: const StringJsonConverter().fromJson(json['status']),
  code: const StringJsonConverter().fromJson(json['code']),
  message: const StringJsonConverter().fromJson(json['message']),
  details: asMapOrNull(json['details']),
);

DownloadClientDiagnosticReportDto _$DownloadClientDiagnosticReportDtoFromJson(
  Map<String, dynamic> json,
) => DownloadClientDiagnosticReportDto(
  status: const StringJsonConverter().fromJson(json['status']),
  checks: _diagnosticChecksFromJson(json['checks']),
  checkedAt: const DateTimeJsonConverter().fromJson(json['checked_at']),
  elapsedMs: const IntJsonConverter().fromJson(json['elapsed_ms']),
);
