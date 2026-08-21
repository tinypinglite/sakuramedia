import 'package:sakuramedia/core/json/json_parse.dart';
import 'package:sakuramedia/features/movies/data/dto/listing/movie_list_item_dto.dart';
import 'package:sakuramedia/features/subscriptions/data/dto/movie_subscription_status.dart';

/// `GET /movie-subscriptions` 的单条订阅影片。
class MovieSubscriptionListItemDto {
  const MovieSubscriptionListItemDto({
    required this.movieId,
    required this.movieNumber,
    required this.title,
    required this.status,
    this.coverImage,
    this.releaseDate,
    this.subscribedAt,
    this.isFresh = false,
    this.attemptCount = 0,
    this.attemptLimit = 0,
    this.lastSearchedAt,
    this.lastError,
    this.deadDownloadTaskCount = 0,
    this.mediaCount = 0,
  });

  final int movieId;
  final String movieNumber;
  final String title;
  final MovieImageDto? coverImage;
  final String? releaseDate;
  final DateTime? subscribedAt;
  final MovieSubscriptionStatus status;
  final bool isFresh;
  final int attemptCount;
  final int attemptLimit;
  final DateTime? lastSearchedAt;
  final String? lastError;
  final int deadDownloadTaskCount;
  final int mediaCount;

  factory MovieSubscriptionListItemDto.fromJson(Map<String, dynamic> json) {
    final coverImage = asMapOrNull(json['cover_image']);
    return MovieSubscriptionListItemDto(
      movieId: asInt(json['movie_id']),
      movieNumber: asStringOrNull(json['movie_number']) ?? '',
      title: asStringOrNull(json['title']) ?? '',
      coverImage: coverImage == null ? null : MovieImageDto.fromJson(coverImage),
      releaseDate: asStringOrNull(json['release_date'], trim: true),
      subscribedAt: asDateTime(json['subscribed_at']),
      status: MovieSubscriptionStatusX.fromWire(json['status']),
      isFresh: json['is_fresh'] as bool? ?? false,
      attemptCount: asInt(json['attempt_count']),
      attemptLimit: asInt(json['attempt_limit']),
      lastSearchedAt: asDateTime(json['last_searched_at']),
      lastError: asStringOrNull(json['last_error'], trim: true),
      deadDownloadTaskCount: asInt(json['dead_download_task_count']),
      mediaCount: asInt(json['media_count']),
    );
  }

  String get displayTitle => title.trim().isNotEmpty ? title : movieNumber;

  String get displayStatusLabel => status.label;

  bool get canResetSearch =>
      status == MovieSubscriptionStatus.missing ||
      status == MovieSubscriptionStatus.exhausted ||
      status == MovieSubscriptionStatus.failed;

}
