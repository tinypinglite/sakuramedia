import 'package:sakuramedia/core/network/paginated_response_dto.dart';
import 'package:sakuramedia/features/movies/data/movie_list_item_dto.dart';

class MomentRecommendationPageDto {
  const MomentRecommendationPageDto({
    required this.items,
    required this.page,
    required this.pageSize,
    required this.total,
    required this.generatedAt,
  });

  final List<MomentRecommendationDto> items;
  final int page;
  final int pageSize;
  final int total;
  final DateTime? generatedAt;

  factory MomentRecommendationPageDto.fromJson(Map<String, dynamic> json) {
    final page = PaginatedResponseDto<MomentRecommendationDto>.fromJson(
      json,
      MomentRecommendationDto.fromJson,
    );
    return MomentRecommendationPageDto(
      items: page.items,
      page: page.page,
      pageSize: page.pageSize,
      total: page.total,
      generatedAt: _dateTimeFromJson(json['generated_at']),
    );
  }
}

class MomentRecommendationDto {
  const MomentRecommendationDto({
    required this.recommendationId,
    required this.rank,
    required this.score,
    required this.strategy,
    required this.reason,
    required this.mediaId,
    required this.thumbnailId,
    required this.offsetSeconds,
    required this.image,
    required this.movie,
  });

  final int recommendationId;
  final int rank;
  final double score;
  final String strategy;
  final String reason;
  final int mediaId;
  final int thumbnailId;
  final int offsetSeconds;
  final MovieImageDto? image;
  final MovieListItemDto movie;

  factory MomentRecommendationDto.fromJson(Map<String, dynamic> json) {
    return MomentRecommendationDto(
      recommendationId: _intFromJson(json['recommendation_id']) ?? 0,
      rank: _intFromJson(json['rank']) ?? 0,
      score: _doubleFromJson(json['score']) ?? 0,
      strategy: json['strategy'] as String? ?? '',
      reason: json['reason'] as String? ?? '',
      mediaId: _intFromJson(json['media_id']) ?? 0,
      thumbnailId: _intFromJson(json['thumbnail_id']) ?? 0,
      offsetSeconds: _intFromJson(json['offset_seconds']) ?? 0,
      image: _movieImageFromJson(json['image']),
      movie: MovieListItemDto.fromJson(_mapFromJson(json['movie'])),
    );
  }
}

DateTime? _dateTimeFromJson(dynamic value) {
  if (value is! String || value.isEmpty) {
    return null;
  }
  return DateTime.tryParse(value);
}

int? _intFromJson(dynamic value) {
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }
  if (value is String) {
    return int.tryParse(value);
  }
  return null;
}

double? _doubleFromJson(dynamic value) {
  if (value is num) {
    return value.toDouble();
  }
  if (value is String) {
    return double.tryParse(value);
  }
  return null;
}

MovieImageDto? _movieImageFromJson(dynamic value) {
  final map = _nullableMapFromJson(value);
  if (map == null) {
    return null;
  }
  return MovieImageDto.fromJson(map);
}

Map<String, dynamic> _mapFromJson(dynamic value) {
  return _nullableMapFromJson(value) ?? const <String, dynamic>{};
}

Map<String, dynamic>? _nullableMapFromJson(dynamic value) {
  if (value is Map<String, dynamic>) {
    return value;
  }
  if (value is Map) {
    return value.map(
      (dynamic key, dynamic data) => MapEntry(key.toString(), data),
    );
  }
  return null;
}
