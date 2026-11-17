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

class DownloadSelectionRejectionDto {
  const DownloadSelectionRejectionDto({
    required this.code,
    required this.message,
    this.groupLabel,
    this.term,
    this.field,
    this.limit,
    this.actual,
  });

  final String code;
  final String message;
  final String? groupLabel;
  final String? term;
  final String? field;
  final int? limit;
  final Object? actual;

  factory DownloadSelectionRejectionDto.fromJson(Map<String, dynamic> json) {
    return DownloadSelectionRejectionDto(
      code: json['code'] as String? ?? '',
      message: json['message'] as String? ?? '',
      groupLabel: json['group_label'] as String?,
      term: json['term'] as String?,
      field: json['field'] as String?,
      limit: json['limit'] as int?,
      actual: json['actual'],
    );
  }
}

class DownloadCandidateSelectionEvaluationDto {
  const DownloadCandidateSelectionEvaluationDto({
    required this.eligible,
    this.rejectionReasons = const <DownloadSelectionRejectionDto>[],
    this.matchedRequiredGroupLabels = const <String>[],
    this.matchedPreferredGroupLabel,
    this.preferenceRank,
    this.selectionRank,
    this.withinAttemptLimit = false,
  });

  final bool eligible;
  final List<DownloadSelectionRejectionDto> rejectionReasons;
  final List<String> matchedRequiredGroupLabels;
  final String? matchedPreferredGroupLabel;
  final int? preferenceRank;
  final int? selectionRank;
  final bool withinAttemptLimit;

  factory DownloadCandidateSelectionEvaluationDto.fromJson(
    Map<String, dynamic> json,
  ) {
    final rawReasons = json['rejection_reasons'];
    final rawLabels = json['matched_required_group_labels'];
    return DownloadCandidateSelectionEvaluationDto(
      eligible: json['eligible'] as bool? ?? false,
      rejectionReasons: rawReasons is List
          ? rawReasons
                .whereType<Map>()
                .map(
                  (item) => DownloadSelectionRejectionDto.fromJson(
                    item.map(
                      (dynamic key, dynamic value) =>
                          MapEntry(key.toString(), value),
                    ),
                  ),
                )
                .toList(growable: false)
          : const <DownloadSelectionRejectionDto>[],
      matchedRequiredGroupLabels: rawLabels is List
          ? rawLabels.whereType<String>().toList(growable: false)
          : const <String>[],
      matchedPreferredGroupLabel:
          json['matched_preferred_group_label'] as String?,
      preferenceRank: json['preference_rank'] as int?,
      selectionRank: json['selection_rank'] as int?,
      withinAttemptLimit: json['within_attempt_limit'] as bool? ?? false,
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
    this.releaseTitle = '',
    this.description = '',
    this.publishedAt,
    required this.sizeBytes,
    required this.seeders,
    this.selectionEvaluation,
  });

  final String sourceUri;
  final String indexerName;
  final String indexerKind;
  final int resolvedClientId;
  final String resolvedClientName;
  final List<DownloadCandidateClientDto> downloadClients;
  final String movieNumber;
  final String title;
  final String releaseTitle;
  final String description;
  final DateTime? publishedAt;
  final int sizeBytes;
  final int seeders;
  final DownloadCandidateSelectionEvaluationDto? selectionEvaluation;

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
      releaseTitle: json['release_title'] as String? ?? '',
      description: json['description'] as String? ?? '',
      publishedAt: DateTime.tryParse(json['published_at'] as String? ?? ''),
      sizeBytes: json['size_bytes'] as int? ?? 0,
      seeders: json['seeders'] as int? ?? 0,
      selectionEvaluation: _parseSelectionEvaluation(
        json['selection_evaluation'],
      ),
    );
  }

  Map<String, dynamic> toCreatePayloadJson() {
    return <String, dynamic>{
      'source_uri': sourceUri,
      'indexer_name': indexerName,
      'title': title,
      'release_title': releaseTitle,
      'description': description,
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

  static DownloadCandidateSelectionEvaluationDto? _parseSelectionEvaluation(
    dynamic value,
  ) {
    if (value is! Map) return null;
    return DownloadCandidateSelectionEvaluationDto.fromJson(
      value.map((dynamic key, dynamic item) => MapEntry(key.toString(), item)),
    );
  }
}
