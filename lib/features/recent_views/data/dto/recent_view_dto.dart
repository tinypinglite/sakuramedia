import 'package:sakuramedia/features/actors/data/dto/actor_list_item_dto.dart';
import 'package:sakuramedia/features/movies/data/dto/listing/movie_list_item_dto.dart';

/// 最近浏览的实体类型：与后端 `view_history.entity_type` 一一对应。
enum RecentViewEntityType {
  movie,
  actor;

  String get apiValue => switch (this) {
    RecentViewEntityType.movie => 'movie',
    RecentViewEntityType.actor => 'actor',
  };

  static RecentViewEntityType? tryParse(String? value) => switch (value) {
    'movie' => RecentViewEntityType.movie,
    'actor' => RecentViewEntityType.actor,
    _ => null,
  };
}

/// 一条浏览记录：直接复用影片/女优的标准列表资源，卡片组件无需另建模型。
class RecentViewEntryDto {
  const RecentViewEntryDto({
    required this.entityType,
    required this.viewedAt,
    this.movie,
    this.actor,
  });

  final RecentViewEntityType entityType;
  final DateTime viewedAt;
  final MovieListItemDto? movie;
  final ActorListItemDto? actor;

  RecentViewEntryDto copyWith({
    MovieListItemDto? movie,
    ActorListItemDto? actor,
  }) {
    return RecentViewEntryDto(
      entityType: entityType,
      viewedAt: viewedAt,
      movie: movie ?? this.movie,
      actor: actor ?? this.actor,
    );
  }

  /// 类型未知、时间非法或与类型不匹配的主体缺失时丢弃，避免污染列表。
  static RecentViewEntryDto? tryFromJson(Map<String, dynamic> json) {
    final entityType = RecentViewEntityType.tryParse(
      json['entity_type'] as String?,
    );
    final viewedAt = DateTime.tryParse(json['viewed_at'] as String? ?? '');
    if (entityType == null || viewedAt == null) {
      return null;
    }
    final movieJson = json['movie'];
    final actorJson = json['actor'];
    final movie = movieJson is Map<String, dynamic>
        ? MovieListItemDto.fromJson(movieJson)
        : null;
    final actor = actorJson is Map<String, dynamic>
        ? ActorListItemDto.fromJson(actorJson)
        : null;
    switch (entityType) {
      case RecentViewEntityType.movie:
        if (movie == null) return null;
      case RecentViewEntityType.actor:
        if (actor == null) return null;
    }
    return RecentViewEntryDto(
      entityType: entityType,
      viewedAt: viewedAt,
      movie: entityType == RecentViewEntityType.movie ? movie : null,
      actor: entityType == RecentViewEntityType.actor ? actor : null,
    );
  }
}
