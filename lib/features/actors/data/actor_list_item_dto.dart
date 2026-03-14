import 'package:sakuramedia/features/movies/data/movie_list_item_dto.dart';

class ActorListItemDto {
  const ActorListItemDto({
    required this.id,
    required this.javdbId,
    required this.name,
    required this.aliasName,
    required this.profileImage,
    required this.isSubscribed,
  });

  final int id;
  final String javdbId;
  final String name;
  final String aliasName;
  final MovieImageDto? profileImage;
  final bool isSubscribed;

  String get displayName => aliasName.trim().isNotEmpty ? aliasName : name;

  ActorListItemDto copyWith({
    int? id,
    String? javdbId,
    String? name,
    String? aliasName,
    MovieImageDto? profileImage,
    bool? isSubscribed,
  }) {
    return ActorListItemDto(
      id: id ?? this.id,
      javdbId: javdbId ?? this.javdbId,
      name: name ?? this.name,
      aliasName: aliasName ?? this.aliasName,
      profileImage: profileImage ?? this.profileImage,
      isSubscribed: isSubscribed ?? this.isSubscribed,
    );
  }

  factory ActorListItemDto.fromJson(Map<String, dynamic> json) {
    return ActorListItemDto(
      id: json['id'] as int? ?? 0,
      javdbId: json['javdb_id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      aliasName: json['alias_name'] as String? ?? '',
      profileImage: _imageFromJson(json['profile_image']),
      isSubscribed: json['is_subscribed'] as bool? ?? false,
    );
  }

  static MovieImageDto? _imageFromJson(dynamic value) {
    if (value is Map<String, dynamic>) {
      return MovieImageDto.fromJson(value);
    }
    if (value is Map) {
      return MovieImageDto.fromJson(
        value.map(
          (dynamic key, dynamic data) => MapEntry(key.toString(), data),
        ),
      );
    }
    return null;
  }
}
