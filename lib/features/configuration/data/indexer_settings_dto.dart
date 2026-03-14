class IndexerEntryDto {
  const IndexerEntryDto({
    required this.id,
    required this.name,
    required this.url,
    required this.kind,
    required this.downloadClientId,
    required this.downloadClientName,
  });

  final int id;
  final String name;
  final String url;
  final String kind;
  final int downloadClientId;
  final String downloadClientName;

  factory IndexerEntryDto.fromJson(Map<String, dynamic> json) {
    return IndexerEntryDto(
      id: json['id'] as int? ?? 0,
      name: json['name'] as String? ?? '',
      url: json['url'] as String? ?? '',
      kind: json['kind'] as String? ?? '',
      downloadClientId: json['download_client_id'] as int? ?? 0,
      downloadClientName: json['download_client_name'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'name': name,
      'url': url,
      'kind': kind,
      'download_client_id': downloadClientId,
    };
  }
}

class IndexerSettingsDto {
  const IndexerSettingsDto({
    required this.type,
    required this.apiKey,
    required this.indexers,
  });

  final String type;
  final String apiKey;
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
      type: json['type'] as String? ?? '',
      apiKey: json['api_key'] as String? ?? '',
      indexers: indexers,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'type': type,
      'api_key': apiKey,
      'indexers': indexers.map((item) => item.toJson()).toList(growable: false),
    };
  }
}

class UpdateIndexerSettingsPayload {
  const UpdateIndexerSettingsPayload({
    required this.type,
    required this.apiKey,
    required this.indexers,
  });

  final String type;
  final String apiKey;
  final List<IndexerEntryDto> indexers;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'type': type,
      'api_key': apiKey,
      'indexers': indexers.map((item) => item.toJson()).toList(growable: false),
    };
  }
}
