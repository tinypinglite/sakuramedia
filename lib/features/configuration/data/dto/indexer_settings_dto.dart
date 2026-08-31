import 'package:sakuramedia/features/configuration/data/dto/download_client_dto.dart';

class IndexerBoundClientDto {
  const IndexerBoundClientDto({
    required this.id,
    required this.name,
    required this.kind,
  });

  final int id;
  final String name;
  final DownloadClientKind kind;

  factory IndexerBoundClientDto.fromJson(Map<String, dynamic> json) {
    return IndexerBoundClientDto(
      id: json['id'] as int? ?? 0,
      name: json['name'] as String? ?? '',
      kind: DownloadClientKindX.fromWire(json['kind']),
    );
  }
}

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
  final List<IndexerBoundClientDto> downloadClients;

  bool get hasApiKey => apiKey?.trim().isNotEmpty ?? false;

  List<int> get downloadClientIds =>
      downloadClients.map((client) => client.id).toList(growable: false);

  String get downloadClientNames =>
      downloadClients.map((client) => client.name).join('、');

  factory IndexerEntryDto.fromJson(Map<String, dynamic> json) {
    return IndexerEntryDto(
      id: json['id'] as int? ?? 0,
      name: json['name'] as String? ?? '',
      url: json['url'] as String? ?? '',
      kind: json['kind'] as String? ?? '',
      apiKey: json['api_key'] as String?,
      downloadClients: _parseBoundClients(json['download_clients']),
    );
  }

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

  static List<IndexerBoundClientDto> _parseBoundClients(dynamic value) {
    if (value is! List) return const <IndexerBoundClientDto>[];
    return value
        .whereType<Map>()
        .map(
          (item) => IndexerBoundClientDto.fromJson(
            item.map(
              (dynamic key, dynamic value) => MapEntry(key.toString(), value),
            ),
          ),
        )
        .toList(growable: false);
  }
}

class IndexerSettingsDto {
  const IndexerSettingsDto({required this.indexers});

  final List<IndexerEntryDto> indexers;

  factory IndexerSettingsDto.fromJson(Map<String, dynamic> json) {
    final rawIndexers = json['indexers'];
    final indexers =
        rawIndexers is List
            ? rawIndexers
                .whereType<Map>()
                .map(
                  (entry) => IndexerEntryDto.fromJson(
                    entry.map(
                      (dynamic key, dynamic value) =>
                          MapEntry(key.toString(), value),
                    ),
                  ),
                )
                .toList(growable: false)
            : const <IndexerEntryDto>[];
    return IndexerSettingsDto(
      indexers: indexers,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'indexers': indexers.map((item) => item.toJson()).toList(growable: false),
    };
  }
}

class UpdateIndexerSettingsPayload {
  const UpdateIndexerSettingsPayload({required this.indexers});

  final List<IndexerEntryDto> indexers;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'indexers': indexers.map((item) => item.toJson()).toList(growable: false),
    };
  }
}

class IndexerConnectionTestErrorDto {
  const IndexerConnectionTestErrorDto({
    required this.type,
    required this.message,
  });

  final String type;
  final String message;

  factory IndexerConnectionTestErrorDto.fromJson(Map<String, dynamic> json) {
    return IndexerConnectionTestErrorDto(
      type: json['type'] as String? ?? '',
      message: json['message'] as String? ?? '',
    );
  }
}

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
  final IndexerConnectionTestErrorDto? error;

  factory IndexerConnectionTestResultDto.fromJson(Map<String, dynamic> json) {
    final rawCheckedAt = json['checked_at'] as String?;
    final rawError = json['error'];
    return IndexerConnectionTestResultDto(
      healthy: json['healthy'] as bool? ?? false,
      checkedAt: rawCheckedAt == null ? null : DateTime.tryParse(rawCheckedAt),
      query: json['query'] as String? ?? '',
      indexersChecked: json['indexers_checked'] as int? ?? 0,
      resultCount: json['result_count'] as int? ?? 0,
      elapsedMs: json['elapsed_ms'] as int? ?? 0,
      error:
          rawError is Map
              ? IndexerConnectionTestErrorDto.fromJson(
                rawError.map(
                  (dynamic key, dynamic value) =>
                      MapEntry(key.toString(), value),
                ),
              )
              : null,
    );
  }
}
