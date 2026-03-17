class CollectionNumberFeaturesDto {
  const CollectionNumberFeaturesDto({
    required this.features,
    required this.syncStats,
  });

  final List<String> features;
  final CollectionNumberFeaturesSyncStatsDto? syncStats;

  factory CollectionNumberFeaturesDto.fromJson(Map<String, dynamic> json) {
    final rawFeatures = json['features'];
    final features =
        rawFeatures is List
            ? rawFeatures
                .whereType<Object?>()
                .map((item) => item?.toString() ?? '')
                .where((item) => item.isNotEmpty)
                .toList(growable: false)
            : const <String>[];
    final rawSyncStats = json['sync_stats'];
    return CollectionNumberFeaturesDto(
      features: features,
      syncStats:
          rawSyncStats is Map
              ? CollectionNumberFeaturesSyncStatsDto.fromJson(
                rawSyncStats.map(
                  (dynamic key, dynamic value) =>
                      MapEntry(key.toString(), value),
                ),
              )
              : null,
    );
  }
}

class CollectionNumberFeaturesSyncStatsDto {
  const CollectionNumberFeaturesSyncStatsDto({
    required this.totalMovies,
    required this.matchedCount,
    required this.updatedToCollectionCount,
    required this.updatedToSingleCount,
    required this.unchangedCount,
  });

  final int totalMovies;
  final int matchedCount;
  final int updatedToCollectionCount;
  final int updatedToSingleCount;
  final int unchangedCount;

  factory CollectionNumberFeaturesSyncStatsDto.fromJson(
    Map<String, dynamic> json,
  ) {
    return CollectionNumberFeaturesSyncStatsDto(
      totalMovies: json['total_movies'] as int? ?? 0,
      matchedCount: json['matched_count'] as int? ?? 0,
      updatedToCollectionCount:
          json['updated_to_collection_count'] as int? ?? 0,
      updatedToSingleCount: json['updated_to_single_count'] as int? ?? 0,
      unchangedCount: json['unchanged_count'] as int? ?? 0,
    );
  }
}

class UpdateCollectionNumberFeaturesPayload {
  const UpdateCollectionNumberFeaturesPayload({required this.features});

  final List<String> features;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{'features': features};
  }
}
