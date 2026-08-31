import 'package:sakuramedia/features/configuration/data/dto/download_client_dto.dart';

class DownloadCandidateClientDto {
  const DownloadCandidateClientDto({
    required this.id,
    required this.name,
    required this.kind,
  });

  final int id;
  final String name;
  final DownloadClientKind kind;

  factory DownloadCandidateClientDto.fromJson(Map<String, dynamic> json) {
    return DownloadCandidateClientDto(
      id: json['id'] as int? ?? 0,
      name: json['name'] as String? ?? '',
      kind: DownloadClientKindX.fromWire(json['kind']),
    );
  }
}

class DownloadCandidateDto {
  const DownloadCandidateDto({
    required this.source,
    required this.indexerName,
    required this.indexerKind,
    required this.resolvedClientId,
    required this.resolvedClientName,
    this.resolvedClientKind = DownloadClientKind.qbittorrent,
    this.downloadClients = const <DownloadCandidateClientDto>[],
    required this.movieNumber,
    required this.title,
    required this.sizeBytes,
    required this.seeders,
    required this.magnetUrl,
    required this.torrentUrl,
    required this.tags,
  });

  final String source;
  final String indexerName;
  final String indexerKind;
  final int resolvedClientId;
  final String resolvedClientName;
  final DownloadClientKind resolvedClientKind;
  final List<DownloadCandidateClientDto> downloadClients;

  List<DownloadCandidateClientDto> get selectableDownloadClients =>
      downloadClients.isNotEmpty
          ? downloadClients
          : <DownloadCandidateClientDto>[
            DownloadCandidateClientDto(
              id: resolvedClientId,
              name: resolvedClientName,
              kind: resolvedClientKind,
            ),
          ];
  final String movieNumber;
  final String title;
  final int sizeBytes;
  final int seeders;
  final String magnetUrl;
  final String torrentUrl;
  final List<String> tags;

  bool get hasDownloadSource =>
      magnetUrl.trim().isNotEmpty || torrentUrl.trim().isNotEmpty;

  String get submitKey =>
      '$indexerName|$indexerKind|$resolvedClientId|$title|$sizeBytes';

  factory DownloadCandidateDto.fromJson(Map<String, dynamic> json) {
    final resolvedClientId = json['resolved_client_id'] as int? ?? 0;
    final resolvedClientName = json['resolved_client_name'] as String? ?? '';
    final resolvedClientKind = DownloadClientKindX.fromWire(
      json['resolved_client_kind'],
    );
    final parsedClients = _parseDownloadClients(json['download_clients']);
    return DownloadCandidateDto(
      source: json['source'] as String? ?? '',
      indexerName: json['indexer_name'] as String? ?? '',
      indexerKind: json['indexer_kind'] as String? ?? '',
      resolvedClientId: resolvedClientId,
      resolvedClientName: resolvedClientName,
      resolvedClientKind: resolvedClientKind,
      downloadClients:
          parsedClients.isNotEmpty
              ? parsedClients
              : <DownloadCandidateClientDto>[
                DownloadCandidateClientDto(
                  id: resolvedClientId,
                  name: resolvedClientName,
                  kind: resolvedClientKind,
                ),
              ],
      movieNumber: json['movie_number'] as String? ?? '',
      title: json['title'] as String? ?? '',
      sizeBytes: json['size_bytes'] as int? ?? 0,
      seeders: json['seeders'] as int? ?? 0,
      magnetUrl: json['magnet_url'] as String? ?? '',
      torrentUrl: json['torrent_url'] as String? ?? '',
      tags: _parseTags(json['tags']),
    );
  }

  Map<String, dynamic> toCreatePayloadJson() {
    return <String, dynamic>{
      'source': source,
      'indexer_name': indexerName,
      'indexer_kind': indexerKind,
      'title': title,
      'size_bytes': sizeBytes,
      'seeders': seeders,
      'magnet_url': magnetUrl,
      'torrent_url': torrentUrl,
      'tags': tags,
    };
  }

  static List<String> _parseTags(dynamic value) {
    if (value is! List) {
      return const <String>[];
    }
    return value
        .whereType<Object?>()
        .map((item) => item?.toString() ?? '')
        .where((item) => item.isNotEmpty)
        .toList(growable: false);
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
