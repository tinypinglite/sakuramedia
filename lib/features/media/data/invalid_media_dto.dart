import 'package:sakuramedia/features/movies/data/movie_list_item_dto.dart';

class InvalidMediaDto {
  const InvalidMediaDto({
    required this.id,
    required this.movieNumber,
    required this.movieTitle,
    required this.coverImage,
    required this.thinCoverImage,
    required this.path,
    required this.libraryId,
    required this.libraryName,
    required this.fileSizeBytes,
    required this.updatedAt,
  });

  final int id;
  final String movieNumber;
  final String? movieTitle;
  final MovieImageDto? coverImage;
  final MovieImageDto? thinCoverImage;
  final String path;
  final int? libraryId;
  final String? libraryName;
  final int fileSizeBytes;
  final DateTime? updatedAt;

  String get displayTitle {
    final title = movieTitle?.trim();
    if (title != null && title.isNotEmpty) {
      return title;
    }
    return '未命名影片';
  }

  String? get preferredCoverUrl {
    final thinUrl = thinCoverImage?.bestAvailableUrl.trim();
    if (thinUrl != null && thinUrl.isNotEmpty) {
      return thinUrl;
    }
    final coverUrl = coverImage?.bestAvailableUrl.trim();
    if (coverUrl != null && coverUrl.isNotEmpty) {
      return coverUrl;
    }
    return null;
  }

  bool get usesThinCover {
    final thinUrl = thinCoverImage?.bestAvailableUrl.trim();
    return thinUrl != null && thinUrl.isNotEmpty;
  }

  factory InvalidMediaDto.fromJson(Map<String, dynamic> json) {
    return InvalidMediaDto(
      id: _toInt(json['id']),
      movieNumber: json['movie_number'] as String? ?? '',
      movieTitle: json['movie_title'] as String?,
      coverImage: _movieImageFromJson(json['cover_image']),
      thinCoverImage: _movieImageFromJson(json['thin_cover_image']),
      path: json['path'] as String? ?? '',
      libraryId: _tryInt(json['library_id']),
      libraryName: json['library_name'] as String?,
      fileSizeBytes: _toInt(json['file_size_bytes']),
      updatedAt: _parseDateTime(json['updated_at']),
    );
  }

  static MovieImageDto? _movieImageFromJson(dynamic value) {
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

  static DateTime? _parseDateTime(dynamic value) {
    if (value is! String || value.trim().isEmpty) {
      return null;
    }
    return DateTime.tryParse(value);
  }

  static int _toInt(dynamic value) => _tryInt(value) ?? 0;

  static int? _tryInt(dynamic value) {
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
}
