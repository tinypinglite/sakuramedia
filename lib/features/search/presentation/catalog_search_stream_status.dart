import 'package:sakuramedia/features/search/data/catalog_search_stream_stats.dart';

class CatalogSearchStreamStatus {
  const CatalogSearchStreamStatus({
    required this.message,
    required this.isRunning,
    required this.isFailure,
    this.current,
    this.total,
    this.stats,
  });

  final String message;
  final bool isRunning;
  final bool isFailure;
  final int? current;
  final int? total;
  final CatalogSearchStreamStats? stats;

  String? get progressLabel {
    if (current == null || total == null) {
      return null;
    }
    return '$current / $total';
  }

  String? get statsLabel {
    final value = stats;
    if (value == null) {
      return null;
    }
    return '共 ${value.total} 条，新增 ${value.createdCount}，已存在 ${value.alreadyExistsCount}，失败 ${value.failedCount}';
  }
}
