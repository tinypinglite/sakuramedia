class CatalogSearchStreamStats {
  const CatalogSearchStreamStats({
    required this.total,
    required this.createdCount,
    required this.alreadyExistsCount,
    required this.failedCount,
  });

  final int total;
  final int createdCount;
  final int alreadyExistsCount;
  final int failedCount;

  factory CatalogSearchStreamStats.fromJson(Map<String, dynamic> json) {
    return CatalogSearchStreamStats(
      total: json['total'] as int? ?? 0,
      createdCount: json['created_count'] as int? ?? 0,
      alreadyExistsCount: json['already_exists_count'] as int? ?? 0,
      failedCount: json['failed_count'] as int? ?? 0,
    );
  }

  factory CatalogSearchStreamStats.fromLooseJson(Map<String, dynamic> json) {
    if (json.containsKey('stats') && json['stats'] is Map) {
      return CatalogSearchStreamStats.fromJson(
        (json['stats'] as Map).map(
          (dynamic key, dynamic value) => MapEntry(key.toString(), value),
        ),
      );
    }
    return CatalogSearchStreamStats.fromJson(json);
  }
}
