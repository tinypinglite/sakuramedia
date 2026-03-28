import 'package:sakuramedia/features/movies/data/movie_list_item_dto.dart';

class MissavThumbnailItemDto {
  const MissavThumbnailItemDto({required this.index, required this.url});

  final int index;
  final String url;

  factory MissavThumbnailItemDto.fromJson(Map<String, dynamic> json) {
    return MissavThumbnailItemDto(
      index: json['index'] as int? ?? 0,
      url: json['url'] as String? ?? '',
    );
  }

  MovieImageDto toMovieImage() {
    return MovieImageDto(
      id: index,
      origin: url,
      small: url,
      medium: url,
      large: url,
    );
  }
}

class MissavThumbnailResultDto {
  const MissavThumbnailResultDto({
    required this.movieNumber,
    required this.source,
    required this.total,
    required this.items,
  });

  final String movieNumber;
  final String source;
  final int total;
  final List<MissavThumbnailItemDto> items;

  factory MissavThumbnailResultDto.fromJson(Map<String, dynamic> json) {
    return MissavThumbnailResultDto(
      movieNumber: json['movie_number'] as String? ?? '',
      source: json['source'] as String? ?? '',
      total: json['total'] as int? ?? 0,
      items: _itemsFromJson(json['items']),
    );
  }

  static List<MissavThumbnailItemDto> _itemsFromJson(dynamic value) {
    if (value is! List) {
      return const <MissavThumbnailItemDto>[];
    }
    return value
        .whereType<Object?>()
        .map((item) => MissavThumbnailItemDto.fromJson(_toMap(item)))
        .toList(growable: false);
  }

  static Map<String, dynamic> _toMap(Object? value) {
    if (value is Map<String, dynamic>) {
      return value;
    }
    if (value is Map) {
      return value.map(
        (dynamic key, dynamic data) => MapEntry(key.toString(), data),
      );
    }
    return const <String, dynamic>{};
  }
}
