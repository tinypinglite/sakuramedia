import 'package:sakuramedia/core/json/json_parse.dart';
import 'package:sakuramedia/features/movies/data/dto/listing/movie_list_item_dto.dart';
import 'package:sakuramedia/features/subscriptions/data/dto/movie_subscription_status.dart';
import 'package:sakuramedia/l10n/app_localizations.dart';

/// `GET /movie-subscriptions` 的单条订阅影片。
class MovieSubscriptionListItemDto with MovieCoverSelection {
  const MovieSubscriptionListItemDto({
    required this.movieId,
    required this.movieNumber,
    required this.title,
    required this.status,
    this.coverImage,
    this.thinCoverImage,
    this.releaseDate,
    this.subscribedAt,
    this.isFresh = false,
    this.attemptCount = 0,
    this.attemptLimit = 0,
    this.lastSearchedAt,
    this.lastError,
    this.importStatus,
    this.importStatusLabel,
    this.deadDownloadTaskCount = 0,
    this.mediaCount = 0,
  });

  final int movieId;
  final String movieNumber;
  final String title;
  @override
  final MovieImageDto? coverImage;
  @override
  final MovieImageDto? thinCoverImage;
  final DateTime? releaseDate;
  final DateTime? subscribedAt;
  final MovieSubscriptionStatus status;
  final bool isFresh;
  final int attemptCount;
  final int attemptLimit;
  final DateTime? lastSearchedAt;
  final String? lastError;
  final String? importStatus;
  final String? importStatusLabel;
  final int deadDownloadTaskCount;
  final int mediaCount;

  factory MovieSubscriptionListItemDto.fromJson(Map<String, dynamic> json) {
    final coverImage = asMapOrNull(json['cover_image']);
    final thinCoverImage = asMapOrNull(json['thin_cover_image']);
    return MovieSubscriptionListItemDto(
      movieId: asInt(json['movie_id']),
      movieNumber: asStringOrNull(json['movie_number']) ?? '',
      title: asStringOrNull(json['title']) ?? '',
      coverImage: coverImage == null
          ? null
          : MovieImageDto.fromJson(coverImage),
      thinCoverImage: thinCoverImage == null
          ? null
          : MovieImageDto.fromJson(thinCoverImage),
      releaseDate: DateTime.tryParse(
        asStringOrNull(json['release_date'], trim: true) ?? '',
      ),
      subscribedAt: asDateTime(json['subscribed_at']),
      status: MovieSubscriptionStatusX.fromWire(json['status']),
      isFresh: json['is_fresh'] as bool? ?? false,
      attemptCount: asInt(json['attempt_count']),
      attemptLimit: asInt(json['attempt_limit']),
      lastSearchedAt: asDateTime(json['last_searched_at']),
      lastError: asStringOrNull(json['last_error'], trim: true),
      importStatus: asStringOrNull(json['import_status'], trim: true),
      importStatusLabel: asStringOrNull(
        json['import_status_label'],
        trim: true,
      ),
      deadDownloadTaskCount: asInt(json['dead_download_task_count']),
      mediaCount: asInt(json['media_count']),
    );
  }

  String get displayTitle => title.trim().isNotEmpty ? title : movieNumber;

  /// 已成功导入（import_status=completed）但媒体已从库中删除：状态仍落在
  /// importFailed（台账行还在、库里没 Media），但归因不是"导入失败"，
  /// 展示层单独区分文案与颜色。
  bool get isImportedMediaRemoved =>
      status == MovieSubscriptionStatus.importFailed &&
      importStatus == 'completed';

  /// 状态标签。调用方负责传入当前语言的 [AppLocalizations]。
  String displayStatusLabel(AppLocalizations l10n) => isImportedMediaRemoved
      ? l10n.subscriptionStatusMediaRemoved
      : status.label(l10n);

  bool get canResetSearch =>
      status == MovieSubscriptionStatus.missing ||
      status == MovieSubscriptionStatus.exhausted ||
      status == MovieSubscriptionStatus.failed;
}
