/// 候选资源允许选择的下载器概要。
class DownloadCandidateClientDto {
  const DownloadCandidateClientDto({required this.id, required this.name});

  final int id;
  final String name;

  factory DownloadCandidateClientDto.fromJson(Map<String, dynamic> json) {
    return DownloadCandidateClientDto(
      id: json['id'] as int? ?? 0,
      name: json['name'] as String? ?? '',
    );
  }
}

class DownloadCandidateDto {
  const DownloadCandidateDto({
    required this.sourceUri,
    required this.indexerName,
    required this.indexerKind,
    required this.resolvedClientId,
    required this.resolvedClientName,
    this.downloadClients = const <DownloadCandidateClientDto>[],
    required this.movieNumber,
    required this.title,
    required this.sizeBytes,
    required this.seeders,
  });

  final String sourceUri;
  final String indexerName;
  final String indexerKind;
  final int resolvedClientId;
  final String resolvedClientName;
  final List<DownloadCandidateClientDto> downloadClients;
  final String movieNumber;
  final String title;
  final int sizeBytes;
  final int seeders;

  /// 后端通常返回候选可选下载器列表；列表为空时仍保留后端解析出的默认下载器。
  List<DownloadCandidateClientDto> get selectableDownloadClients {
    if (downloadClients.isNotEmpty) {
      return downloadClients;
    }
    return <DownloadCandidateClientDto>[
      DownloadCandidateClientDto(
        id: resolvedClientId,
        name: resolvedClientName,
      ),
    ];
  }

  bool get hasDownloadSource => sourceUri.trim().isNotEmpty;

  String get submitKey =>
      '$indexerName|$indexerKind|$resolvedClientId|$title|$sizeBytes';

  factory DownloadCandidateDto.fromJson(Map<String, dynamic> json) {
    final resolvedClientId = json['resolved_client_id'] as int? ?? 0;
    final resolvedClientName = json['resolved_client_name'] as String? ?? '';
    final parsedClients = _parseDownloadClients(json['download_clients']);
    return DownloadCandidateDto(
      sourceUri: json['source_uri'] as String? ?? '',
      indexerName: json['indexer_name'] as String? ?? '',
      indexerKind: json['indexer_kind'] as String? ?? '',
      resolvedClientId: resolvedClientId,
      resolvedClientName: resolvedClientName,
      downloadClients: parsedClients.isNotEmpty
          ? parsedClients
          : <DownloadCandidateClientDto>[
              DownloadCandidateClientDto(
                id: resolvedClientId,
                name: resolvedClientName,
              ),
            ],
      movieNumber: json['movie_number'] as String? ?? '',
      title: json['title'] as String? ?? '',
      sizeBytes: json['size_bytes'] as int? ?? 0,
      seeders: json['seeders'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toCreatePayloadJson() {
    return <String, dynamic>{
      'source_uri': sourceUri,
      'title': title,
      'size_bytes': sizeBytes,
      'seeders': seeders,
    };
  }

  static List<DownloadCandidateClientDto> _parseDownloadClients(dynamic value) {
    if (value is! List) return const <DownloadCandidateClientDto>[];
    return value
        .whereType<Map>()
        .map(
          (item) => DownloadCandidateClientDto.fromJson(
            item.map(
              (dynamic key, dynamic value) => MapEntry(key.toString(), value),
            ),
          ),
        )
        .toList(growable: false);
  }
}
