import 'package:sakuramedia/core/json/json_parse.dart';

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
    final items = rawItems is List
        ? <T>[
            for (final item in rawItems)
              if (asMapOrNull(item) case final map?) itemFromJson(map),
          ]
        : <T>[];

    return PaginatedResponseDto<T>(
      items: items,
      page: asInt(json['page'], fallback: 1),
      pageSize: asInt(json['page_size'], fallback: 20),
      total: asInt(json['total']),
      syncedAt: asDateTime(json['synced_at']),
    );
  }
}
