import 'package:sakuramedia/core/json/json_parse.dart';

/// 后端批量订阅/取消订阅端点的 `skipped` 原因码。
enum MovieSubscriptionSkipReason {
  /// 番号未在库内命中。
  movieNotFound,

  /// 影片存在关联的本地 media，取消订阅时静默跳过。
  hasMedia,

  /// 未识别的原因码，兜底给前端展示原始字符串。
  unknown;

  static MovieSubscriptionSkipReason fromWire(String? raw) {
    switch (raw) {
      case 'movie_not_found':
        return MovieSubscriptionSkipReason.movieNotFound;
      case 'has_media':
        return MovieSubscriptionSkipReason.hasMedia;
      default:
        return MovieSubscriptionSkipReason.unknown;
    }
  }
}

class MovieSubscriptionSkippedItemDto {
  const MovieSubscriptionSkippedItemDto({
    required this.movieNumber,
    required this.reason,
    required this.rawReason,
  });

  final String movieNumber;
  final MovieSubscriptionSkipReason reason;

  /// 保留原始字符串，便于日志/未来新增原因的兜底展示。
  final String rawReason;

  factory MovieSubscriptionSkippedItemDto.fromJson(Map<String, dynamic> json) {
    final rawReason = asStringOrNull(json['reason']) ?? '';
    return MovieSubscriptionSkippedItemDto(
      movieNumber: asStringOrNull(json['movie_number']) ?? '',
      reason: MovieSubscriptionSkipReason.fromWire(rawReason),
      rawReason: rawReason,
    );
  }
}

class MovieSubscriptionBatchResultDto {
  const MovieSubscriptionBatchResultDto({
    required this.requestedCount,
    required this.updatedCount,
    required this.skippedCount,
    required this.skipped,
  });

  final int requestedCount;
  final int updatedCount;
  final int skippedCount;
  final List<MovieSubscriptionSkippedItemDto> skipped;

  List<String> movieNumbersSkippedBecause(MovieSubscriptionSkipReason reason) =>
      [
        for (final item in skipped)
          if (item.reason == reason && item.movieNumber.isNotEmpty)
            item.movieNumber,
      ];

  factory MovieSubscriptionBatchResultDto.fromJson(Map<String, dynamic> json) {
    final rawList = json['skipped'];
    final skipped = <MovieSubscriptionSkippedItemDto>[];
    if (rawList is List) {
      for (final item in rawList) {
        final map = asMapOrNull(item);
        if (map == null) continue;
        skipped.add(MovieSubscriptionSkippedItemDto.fromJson(map));
      }
    }
    return MovieSubscriptionBatchResultDto(
      requestedCount: asInt(json['requested_count']),
      updatedCount: asInt(json['updated_count']),
      skippedCount: asInt(json['skipped_count']),
      skipped: skipped,
    );
  }
}
