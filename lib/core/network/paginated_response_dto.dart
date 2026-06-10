class PaginatedResponseDto<T> {
  const PaginatedResponseDto({
    required this.items,
    required this.page,
    required this.pageSize,
    required this.total,
    this.syncedAt,
  });

  final List<T> items;
  final int page;
  final int pageSize;
  final int total;

  /// 当前这批数据的抓取时间（本地时区），整批共用同一个值。
  /// 该周期/榜单暂无数据时为 `null`。与条目内的 `created_at` 含义不同。
  final DateTime? syncedAt;

  factory PaginatedResponseDto.fromJson(
    Map<String, dynamic> json,
    T Function(Map<String, dynamic> json) itemFromJson,
  ) {
    final rawItems = json['items'];
    final items =
        rawItems is List
            ? rawItems
                .whereType<Map>()
                .map(
                  (item) => itemFromJson(
                    item.map(
                      (dynamic key, dynamic value) =>
                          MapEntry(key.toString(), value),
                    ),
                  ),
                )
                .toList(growable: false)
            : <T>[];

    return PaginatedResponseDto<T>(
      items: items,
      page: json['page'] as int? ?? 1,
      pageSize: json['page_size'] as int? ?? 20,
      total: json['total'] as int? ?? 0,
      syncedAt: _syncedAtFromJson(json['synced_at']),
    );
  }
}

DateTime? _syncedAtFromJson(dynamic value) {
  if (value is! String || value.isEmpty) {
    return null;
  }
  return DateTime.tryParse(value);
}
