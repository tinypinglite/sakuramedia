// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'indexer_settings_dto.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

IndexerBoundClientDto _$IndexerBoundClientDtoFromJson(
  Map<String, dynamic> json,
) => IndexerBoundClientDto(
  id: const IntJsonConverter().fromJson(json['id']),
  name: const StringJsonConverter().fromJson(json['name']),
);

IndexerEntryDto _$IndexerEntryDtoFromJson(Map<String, dynamic> json) =>
    IndexerEntryDto(
      id: const IntJsonConverter().fromJson(json['id']),
      name: const StringJsonConverter().fromJson(json['name']),
      url: const StringJsonConverter().fromJson(json['url']),
      kind: const StringJsonConverter().fromJson(json['kind']),
      apiKey: const NullableStringJsonConverter().fromJson(json['api_key']),
      downloadClients: _boundClientsFromJson(json['download_clients']),
    );

IndexerSettingsDto _$IndexerSettingsDtoFromJson(Map<String, dynamic> json) =>
    IndexerSettingsDto(indexers: _indexersFromJson(json['indexers']));

Map<String, dynamic> _$IndexerSettingsDtoToJson(IndexerSettingsDto instance) =>
    <String, dynamic>{
      'indexers': instance.indexers.map((e) => e.toJson()).toList(),
    };

Map<String, dynamic> _$UpdateIndexerSettingsPayloadToJson(
  UpdateIndexerSettingsPayload instance,
) => <String, dynamic>{
  'indexers': instance.indexers.map((e) => e.toJson()).toList(),
};

IndexerConnectionTestErrorDto _$IndexerConnectionTestErrorDtoFromJson(
  Map<String, dynamic> json,
) => IndexerConnectionTestErrorDto(
  type: const StringJsonConverter().fromJson(json['type']),
  message: const StringJsonConverter().fromJson(json['message']),
);

IndexerConnectionTestResultDto _$IndexerConnectionTestResultDtoFromJson(
  Map<String, dynamic> json,
) => IndexerConnectionTestResultDto(
  healthy: const BoolJsonConverter().fromJson(json['healthy']),
  checkedAt: const DateTimeJsonConverter().fromJson(json['checked_at']),
  query: const StringJsonConverter().fromJson(json['query']),
  indexersChecked: const IntJsonConverter().fromJson(json['indexers_checked']),
  resultCount: const IntJsonConverter().fromJson(json['result_count']),
  elapsedMs: const IntJsonConverter().fromJson(json['elapsed_ms']),
  error: _testErrorFromJson(json['error']),
);
