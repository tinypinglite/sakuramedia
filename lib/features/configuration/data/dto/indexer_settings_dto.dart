import 'package:json_annotation/json_annotation.dart';
import 'package:sakuramedia/core/json/dto_json_codec.dart';
import 'package:sakuramedia/core/json/json_parse.dart';

part 'indexer_settings_dto.g.dart';

@JsonSerializable(converters: dtoJsonConverters, createToJson: false)
class IndexerBoundClientDto {
  const IndexerBoundClientDto({required this.id, required this.name});

  final int id;
  final String name;

  factory IndexerBoundClientDto.fromJson(Map<String, dynamic> json) =>
      _$IndexerBoundClientDtoFromJson(json);
}

@JsonSerializable(converters: dtoJsonConverters, createToJson: false)
class IndexerEntryDto {
  const IndexerEntryDto({
    required this.id,
    required this.name,
    required this.url,
    required this.kind,
    this.apiKey,
    required this.downloadClients,
  });

  final int id;
  final String name;
  final String url;
  final String kind;

  /// 每个索引器独立的 Torznab 鉴权 key；为空表示请求不携带 apikey。
  final String? apiKey;
  @JsonKey(fromJson: _boundClientsFromJson)
  final List<IndexerBoundClientDto> downloadClients;

  bool get hasApiKey => apiKey?.trim().isNotEmpty ?? false;

  List<int> get downloadClientIds =>
      downloadClients.map((client) => client.id).toList(growable: false);

  String get downloadClientNames =>
      downloadClients.map((client) => client.name).join('、');

  factory IndexerEntryDto.fromJson(Map<String, dynamic> json) =>
      _$IndexerEntryDtoFromJson(json);

  Map<String, dynamic> toJson() {
    final key = apiKey?.trim() ?? '';
    return <String, dynamic>{
      'name': name,
      'url': url,
      'kind': kind,
      'api_key': key.isEmpty ? null : key,
      'download_client_ids': downloadClientIds,
    };
  }
}

@JsonSerializable(converters: dtoJsonConverters, explicitToJson: true)
class IndexerSettingsDto {
  const IndexerSettingsDto({required this.indexers});

  @JsonKey(fromJson: _indexersFromJson)
  final List<IndexerEntryDto> indexers;

  factory IndexerSettingsDto.fromJson(Map<String, dynamic> json) =>
      _$IndexerSettingsDtoFromJson(json);

  Map<String, dynamic> toJson() => _$IndexerSettingsDtoToJson(this);
}

@JsonSerializable(explicitToJson: true, createFactory: false)
class UpdateIndexerSettingsPayload {
  const UpdateIndexerSettingsPayload({required this.indexers});

  final List<IndexerEntryDto> indexers;

  Map<String, dynamic> toJson() => _$UpdateIndexerSettingsPayloadToJson(this);
}

@JsonSerializable(converters: dtoJsonConverters, createToJson: false)
class IndexerConnectionTestErrorDto {
  const IndexerConnectionTestErrorDto({
    required this.type,
    required this.message,
  });

  final String type;
  final String message;

  factory IndexerConnectionTestErrorDto.fromJson(Map<String, dynamic> json) =>
      _$IndexerConnectionTestErrorDtoFromJson(json);
}

@JsonSerializable(converters: dtoJsonConverters, createToJson: false)
class IndexerConnectionTestResultDto {
  const IndexerConnectionTestResultDto({
    required this.healthy,
    required this.checkedAt,
    required this.query,
    required this.indexersChecked,
    required this.resultCount,
    required this.elapsedMs,
    required this.error,
  });

  final bool healthy;
  final DateTime? checkedAt;
  final String query;
  final int indexersChecked;
  final int resultCount;
  final int elapsedMs;
  @JsonKey(fromJson: _testErrorFromJson)
  final IndexerConnectionTestErrorDto? error;

  factory IndexerConnectionTestResultDto.fromJson(Map<String, dynamic> json) =>
      _$IndexerConnectionTestResultDtoFromJson(json);
}

List<IndexerBoundClientDto> _boundClientsFromJson(Object? value) =>
    asObjectList(value, IndexerBoundClientDto.fromJson);

List<IndexerEntryDto> _indexersFromJson(Object? value) =>
    asObjectList(value, IndexerEntryDto.fromJson);

IndexerConnectionTestErrorDto? _testErrorFromJson(Object? value) =>
    asObjectOrNull(value, IndexerConnectionTestErrorDto.fromJson);
