import 'package:sakuramedia/core/json/json_parse.dart';
import 'package:sakuramedia/features/subscriptions/data/dto/movie_subscription_status.dart';

/// `GET /movie-subscriptions/status-counts`：一次 `GROUP BY` 算齐全部状态计数，
/// 供状态分段签的角标使用——前端不需要为每个签各打一次 COUNT。
///
/// 七项之和恒等于 [total]（状态由同一个 SQL CASE 判定，严格互斥）。
class MovieSubscriptionStatusCountsDto {
  const MovieSubscriptionStatusCountsDto({
    this.total = 0,
    this.imported = 0,
    this.importFailed = 0,
    this.downloading = 0,
    this.pending = 0,
    this.missing = 0,
    this.exhausted = 0,
    this.failed = 0,
  });

  static const MovieSubscriptionStatusCountsDto empty =
      MovieSubscriptionStatusCountsDto();

  final int total;
  final int imported;
  final int importFailed;
  final int downloading;
  final int pending;
  final int missing;
  final int exhausted;
  final int failed;

  factory MovieSubscriptionStatusCountsDto.fromJson(Map<String, dynamic> json) {
    return MovieSubscriptionStatusCountsDto(
      total: asInt(json['total']),
      imported: asInt(json['imported']),
      importFailed: asInt(json['import_failed']),
      downloading: asInt(json['downloading']),
      pending: asInt(json['pending']),
      missing: asInt(json['missing']),
      exhausted: asInt(json['exhausted']),
      failed: asInt(json['failed']),
    );
  }

  /// 按状态取计数；[status] 为 `null` 表示「全部」，返回 [total]。
  ///
  /// [MovieSubscriptionStatus.unknown] 没有对应计数字段（后端不会下发未知状态的
  /// 分组），返回 0。
  int countOf(MovieSubscriptionStatus? status) => switch (status) {
    null => total,
    MovieSubscriptionStatus.imported => imported,
    MovieSubscriptionStatus.downloading => downloading,
    MovieSubscriptionStatus.importFailed => importFailed,
    MovieSubscriptionStatus.pending => pending,
    MovieSubscriptionStatus.missing => missing,
    MovieSubscriptionStatus.exhausted => exhausted,
    MovieSubscriptionStatus.failed => failed,
    MovieSubscriptionStatus.unknown => 0,
  };
}
