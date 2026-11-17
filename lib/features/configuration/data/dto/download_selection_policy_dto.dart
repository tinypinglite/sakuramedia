import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:sakuramedia/features/downloads/data/download_candidate_dto.dart';

enum DownloadSelectionRanking {
  sizeDesc('size_desc'),
  seedersDesc('seeders_desc'),
  publishedAtDesc('published_at_desc'),
  indexerPriority('indexer_priority');

  const DownloadSelectionRanking(this.apiValue);

  final String apiValue;

  static DownloadSelectionRanking fromApiValue(String value) {
    return values.firstWhere(
      (item) => item.apiValue == value,
      orElse: () => DownloadSelectionRanking.sizeDesc,
    );
  }
}

@immutable
class DownloadSelectionKeywordGroupDto {
  const DownloadSelectionKeywordGroupDto({this.label, required this.terms});

  final String? label;
  final List<String> terms;

  factory DownloadSelectionKeywordGroupDto.fromJson(Map<String, dynamic> json) {
    return DownloadSelectionKeywordGroupDto(
      label: (json['label'] as String?)?.trim().isEmpty ?? true
          ? null
          : (json['label'] as String).trim(),
      terms: _stringList(json['terms']),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'label': label?.trim().isEmpty ?? true ? null : label!.trim(),
      'terms': terms,
    };
  }

  DownloadSelectionKeywordGroupDto copyWith({
    Object? label = _sentinel,
    List<String>? terms,
  }) {
    return DownloadSelectionKeywordGroupDto(
      label: identical(label, _sentinel) ? this.label : label as String?,
      terms: terms ?? this.terms,
    );
  }
}

@immutable
class DownloadSelectionRulesDto {
  const DownloadSelectionRulesDto({
    this.schemaVersion = 1,
    this.indexerKinds = const <String>[],
    this.indexerNames = const <String>[],
    this.minSizeBytes = 1024 * 1024 * 1024,
    this.maxSizeBytes = 40 * 1024 * 1024 * 1024,
    this.minSeeders = 1,
    this.maxAgeDays,
    this.matchTitle = true,
    this.matchDescription = true,
    this.requiredGroups = const <DownloadSelectionKeywordGroupDto>[],
    this.excludedTerms = const <String>[],
    this.preferredGroups = const <DownloadSelectionKeywordGroupDto>[],
    this.ranking = const <DownloadSelectionRanking>[
      DownloadSelectionRanking.sizeDesc,
    ],
    this.indexerPriorityNames = const <String>[],
  });

  final int schemaVersion;
  final List<String> indexerKinds;
  final List<String> indexerNames;
  final int minSizeBytes;
  final int? maxSizeBytes;
  final int minSeeders;
  final int? maxAgeDays;
  final bool matchTitle;
  final bool matchDescription;
  final List<DownloadSelectionKeywordGroupDto> requiredGroups;
  final List<String> excludedTerms;
  final List<DownloadSelectionKeywordGroupDto> preferredGroups;
  final List<DownloadSelectionRanking> ranking;
  final List<String> indexerPriorityNames;

  factory DownloadSelectionRulesDto.fromJson(Map<String, dynamic> json) {
    final rawRanking = json['ranking'];
    return DownloadSelectionRulesDto(
      schemaVersion: json['schema_version'] as int? ?? 1,
      indexerKinds: _stringList(json['indexer_kinds']),
      indexerNames: _stringList(json['indexer_names']),
      minSizeBytes: json['min_size_bytes'] as int? ?? 1024 * 1024 * 1024,
      maxSizeBytes: json['max_size_bytes'] as int?,
      minSeeders: json['min_seeders'] as int? ?? 1,
      maxAgeDays: json['max_age_days'] as int?,
      matchTitle: json['match_title'] as bool? ?? true,
      matchDescription: json['match_description'] as bool? ?? true,
      requiredGroups: _keywordGroups(json['required_groups']),
      excludedTerms: _stringList(json['excluded_terms']),
      preferredGroups: _keywordGroups(json['preferred_groups']),
      ranking: rawRanking is List && rawRanking.isNotEmpty
          ? rawRanking
                .whereType<String>()
                .map(DownloadSelectionRanking.fromApiValue)
                .toList(growable: false)
          : const <DownloadSelectionRanking>[DownloadSelectionRanking.sizeDesc],
      indexerPriorityNames: _stringList(json['indexer_priority_names']),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'schema_version': schemaVersion,
      'indexer_kinds': indexerKinds,
      'indexer_names': indexerNames,
      'min_size_bytes': minSizeBytes,
      'max_size_bytes': maxSizeBytes,
      'min_seeders': minSeeders,
      'max_age_days': maxAgeDays,
      'match_title': matchTitle,
      'match_description': matchDescription,
      'required_groups': requiredGroups
          .map((group) => group.toJson())
          .toList(growable: false),
      'excluded_terms': excludedTerms,
      'preferred_groups': preferredGroups
          .map((group) => group.toJson())
          .toList(growable: false),
      'ranking': ranking.map((item) => item.apiValue).toList(growable: false),
      'indexer_priority_names': indexerPriorityNames,
    };
  }

  String get semanticFingerprint => jsonEncode(toJson());

  DownloadSelectionRulesDto copyWith({
    int? schemaVersion,
    List<String>? indexerKinds,
    List<String>? indexerNames,
    int? minSizeBytes,
    Object? maxSizeBytes = _sentinel,
    int? minSeeders,
    Object? maxAgeDays = _sentinel,
    bool? matchTitle,
    bool? matchDescription,
    List<DownloadSelectionKeywordGroupDto>? requiredGroups,
    List<String>? excludedTerms,
    List<DownloadSelectionKeywordGroupDto>? preferredGroups,
    List<DownloadSelectionRanking>? ranking,
    List<String>? indexerPriorityNames,
  }) {
    return DownloadSelectionRulesDto(
      schemaVersion: schemaVersion ?? this.schemaVersion,
      indexerKinds: indexerKinds ?? this.indexerKinds,
      indexerNames: indexerNames ?? this.indexerNames,
      minSizeBytes: minSizeBytes ?? this.minSizeBytes,
      maxSizeBytes: identical(maxSizeBytes, _sentinel)
          ? this.maxSizeBytes
          : maxSizeBytes as int?,
      minSeeders: minSeeders ?? this.minSeeders,
      maxAgeDays: identical(maxAgeDays, _sentinel)
          ? this.maxAgeDays
          : maxAgeDays as int?,
      matchTitle: matchTitle ?? this.matchTitle,
      matchDescription: matchDescription ?? this.matchDescription,
      requiredGroups: requiredGroups ?? this.requiredGroups,
      excludedTerms: excludedTerms ?? this.excludedTerms,
      preferredGroups: preferredGroups ?? this.preferredGroups,
      ranking: ranking ?? this.ranking,
      indexerPriorityNames: indexerPriorityNames ?? this.indexerPriorityNames,
    );
  }
}

@immutable
class DownloadSelectionPolicyDto {
  const DownloadSelectionPolicyDto({
    required this.rules,
    required this.version,
    required this.createdAt,
    required this.updatedAt,
  });

  final DownloadSelectionRulesDto rules;
  final int version;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  factory DownloadSelectionPolicyDto.fromJson(Map<String, dynamic> json) {
    final rawRules = json['rules'];
    return DownloadSelectionPolicyDto(
      rules: rawRules is Map
          ? DownloadSelectionRulesDto.fromJson(_stringMap(rawRules))
          : const DownloadSelectionRulesDto(),
      version: json['version'] as int? ?? 1,
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? ''),
      updatedAt: DateTime.tryParse(json['updated_at'] as String? ?? ''),
    );
  }
}

@immutable
class DownloadSelectionPolicyUpdatePayload {
  const DownloadSelectionPolicyUpdatePayload({
    required this.expectedVersion,
    required this.rules,
  });

  final int expectedVersion;
  final DownloadSelectionRulesDto rules;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'expected_version': expectedVersion,
      'rules': rules.toJson(),
    };
  }
}

@immutable
class DownloadSelectionPreviewDto {
  const DownloadSelectionPreviewDto({
    required this.draft,
    required this.policyVersion,
    required this.rawCandidateCount,
    required this.systemCandidateCount,
    required this.eligibleCandidateCount,
    required this.policyFilteredCount,
    required this.rejectionCounts,
    required this.selectedSourceUri,
    required this.candidates,
  });

  final bool draft;
  final int? policyVersion;
  final int rawCandidateCount;
  final int systemCandidateCount;
  final int eligibleCandidateCount;
  final int policyFilteredCount;
  final Map<String, int> rejectionCounts;
  final String? selectedSourceUri;
  final List<DownloadCandidateDto> candidates;

  factory DownloadSelectionPreviewDto.fromJson(Map<String, dynamic> json) {
    final rawCounts = json['rejection_counts'];
    final rejectionCounts = <String, int>{};
    if (rawCounts is Map) {
      for (final entry in rawCounts.entries) {
        final value = entry.value;
        if (value is int) rejectionCounts[entry.key.toString()] = value;
      }
    }
    final rawCandidates = json['candidates'];
    return DownloadSelectionPreviewDto(
      draft: json['draft'] as bool? ?? false,
      policyVersion: json['policy_version'] as int?,
      rawCandidateCount: json['raw_candidate_count'] as int? ?? 0,
      systemCandidateCount: json['system_candidate_count'] as int? ?? 0,
      eligibleCandidateCount: json['eligible_candidate_count'] as int? ?? 0,
      policyFilteredCount: json['policy_filtered_count'] as int? ?? 0,
      rejectionCounts: rejectionCounts,
      selectedSourceUri: json['selected_source_uri'] as String?,
      candidates: rawCandidates is List
          ? rawCandidates
                .whereType<Map>()
                .map((item) => DownloadCandidateDto.fromJson(_stringMap(item)))
                .toList(growable: false)
          : const <DownloadCandidateDto>[],
    );
  }
}

const Object _sentinel = Object();

List<String> _stringList(dynamic value) {
  if (value is! List) return const <String>[];
  return value
      .whereType<String>()
      .map((item) => item.trim())
      .where((item) => item.isNotEmpty)
      .toList(growable: false);
}

List<DownloadSelectionKeywordGroupDto> _keywordGroups(dynamic value) {
  if (value is! List) return const <DownloadSelectionKeywordGroupDto>[];
  return value
      .whereType<Map>()
      .map(
        (item) => DownloadSelectionKeywordGroupDto.fromJson(_stringMap(item)),
      )
      .toList(growable: false);
}

Map<String, dynamic> _stringMap(Map<dynamic, dynamic> value) {
  return value.map(
    (dynamic key, dynamic item) => MapEntry(key.toString(), item),
  );
}
