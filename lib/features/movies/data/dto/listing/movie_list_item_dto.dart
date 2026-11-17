import 'package:sakuramedia/features/movies/data/dto/listing/subscription_movie_list_item.dart';

class MovieImageDto {
  const MovieImageDto({required this.id, required this.origin});

  final int id;
  final String origin;

  factory MovieImageDto.fromJson(Map<String, dynamic> json) {
    return MovieImageDto(
      id: json['id'] as int? ?? 0,
      origin: json['origin'] as String? ?? '',
    );
  }
}

/// 解析图片对象；容忍 `Map` 与 `Map<String, dynamic>`，非对象返回 null。
MovieImageDto? movieImageFromJson(dynamic value) {
  if (value is Map<String, dynamic>) {
    return MovieImageDto.fromJson(value);
  }
  if (value is Map) {
    return MovieImageDto.fromJson(
      value.map((dynamic key, dynamic data) => MapEntry(key.toString(), data)),
    );
  }
  return null;
}

/// 「主封面 + 窄封面」两图选择逻辑：列表行卡在桌面用宽图、移动用窄图；
/// 用图与框方向一致才裁切（`cover`），回退到另一方向的图时居中留边（`contain`）。
///
/// 供 `MediaListItemDto` / `MovieSubscriptionListItemDto` 等带
/// `coverImage` + `thinCoverImage` 的 DTO 复用，避免同一段选择逻辑复制多份。
mixin MovieCoverSelection {
  MovieImageDto? get coverImage;
  MovieImageDto? get thinCoverImage;

  bool get usesThinCover {
    final thinUrl = thinCoverImage?.origin.trim();
    return thinUrl != null && thinUrl.isNotEmpty;
  }

  bool get hasWideCover {
    final coverUrl = coverImage?.origin.trim();
    return coverUrl != null && coverUrl.isNotEmpty;
  }

  /// 窄图优先（移动端行卡用），缺失时退回宽图。
  String? get preferredCoverUrl {
    final thinUrl = thinCoverImage?.origin.trim();
    if (thinUrl != null && thinUrl.isNotEmpty) {
      return thinUrl;
    }
    final coverUrl = coverImage?.origin.trim();
    return coverUrl != null && coverUrl.isNotEmpty ? coverUrl : null;
  }

  /// 宽图优先（桌面行卡用），缺失时退回窄图。
  String? get wideCoverUrl {
    final coverUrl = coverImage?.origin.trim();
    if (coverUrl != null && coverUrl.isNotEmpty) {
      return coverUrl;
    }
    final thinUrl = thinCoverImage?.origin.trim();
    return thinUrl != null && thinUrl.isNotEmpty ? thinUrl : null;
  }
}

class MovieListItemDto implements SubscriptionMovieListItem<MovieListItemDto> {
  const MovieListItemDto({
    this.id = 0,
    required this.movieNumber,
    required this.title,
    this.seriesId,
    this.seriesName = '',
    required this.coverImage,
    this.thinCoverImage,
    required this.releaseDate,
    required this.durationMinutes,
    required this.heat,
    required this.isSubscribed,
    required this.canPlay,
    this.similarityScore,
    this.maxMediaWidth = 0,
    this.myScore,
    this.myRatingValues = const <int, int>{},
  });

  /// 后端返回的影片整数主键，可用于与订阅等域数据关联。
  final int id;

  @override
  final String movieNumber;
  final String title;
  final int? seriesId;
  final String seriesName;
  final MovieImageDto? coverImage;
  final MovieImageDto? thinCoverImage;
  final DateTime? releaseDate;
  final int durationMinutes;
  final int heat;
  @override
  final bool isSubscribed;
  final bool canPlay;
  final double? similarityScore;
  final int maxMediaWidth;

  /// 个人评分总分（1-5）；未评分为 `null`。
  final double? myScore;

  /// 维度 id -> 分值；已评分列表中由后端附带，用于展示维度摘要。
  final Map<int, int> myRatingValues;

  /// DMM 中文标题字段已随后端下线（存量收拢进 [title]），这里保留 getter 只做 trim。
  String get preferredTitle => title.trim();

  MovieListItemDto copyWith({
    String? movieNumber,
    String? title,
    int? seriesId,
    String? seriesName,
    MovieImageDto? coverImage,
    MovieImageDto? thinCoverImage,
    DateTime? releaseDate,
    int? durationMinutes,
    int? heat,
    bool? isSubscribed,
    bool? canPlay,
    double? similarityScore,
    double? myScore,
    Map<int, int>? myRatingValues,
  }) {
    return MovieListItemDto(
      // id 是不可变主键，copyWith 不开放改写、只透传（漏传会被默认 0 抹掉）。
      id: id,
      maxMediaWidth: maxMediaWidth,
      movieNumber: movieNumber ?? this.movieNumber,
      title: title ?? this.title,
      seriesId: seriesId ?? this.seriesId,
      seriesName: seriesName ?? this.seriesName,
      coverImage: coverImage ?? this.coverImage,
      thinCoverImage: thinCoverImage ?? this.thinCoverImage,
      releaseDate: releaseDate ?? this.releaseDate,
      durationMinutes: durationMinutes ?? this.durationMinutes,
      heat: heat ?? this.heat,
      isSubscribed: isSubscribed ?? this.isSubscribed,
      canPlay: canPlay ?? this.canPlay,
      similarityScore: similarityScore ?? this.similarityScore,
      myScore: myScore ?? this.myScore,
      myRatingValues: myRatingValues ?? this.myRatingValues,
    );
  }

  @override
  MovieListItemDto copyWithSubscriptionStatus(bool isSubscribed) =>
      copyWith(isSubscribed: isSubscribed);

  factory MovieListItemDto.fromJson(Map<String, dynamic> json) {
    return MovieListItemDto(
      id: _intFromJson(json['id']) ?? 0,
      maxMediaWidth: _maxMediaWidthFromJson(json['media_items']),
      movieNumber: json['movie_number'] as String? ?? '',
      title: json['title'] as String? ?? '',
      seriesId: _intFromJson(json['series_id']),
      seriesName: json['series_name'] as String? ?? '',
      coverImage: _movieImageFromJson(json['cover_image']),
      thinCoverImage: _movieImageFromJson(json['thin_cover_image']),
      releaseDate: _dateFromJson(json['release_date']),
      durationMinutes: json['duration_minutes'] as int? ?? 0,
      heat: json['heat'] as int? ?? 0,
      isSubscribed: json['is_subscribed'] as bool? ?? false,
      canPlay: json['can_play'] as bool? ?? false,
      similarityScore: _doubleFromJson(json['similarity_score']),
      myScore: _doubleFromJson(json['my_score']),
      myRatingValues: _ratingValuesFromJson(json['my_rating_values']),
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

  static DateTime? _dateFromJson(dynamic value) {
    if (value is! String || value.isEmpty) {
      return null;
    }
    return DateTime.tryParse(value);
  }

  static double? _doubleFromJson(dynamic value) {
    if (value is num) {
      return value.toDouble();
    }
    return null;
  }

  static Map<int, int> _ratingValuesFromJson(dynamic value) {
    if (value is! Map) {
      return const <int, int>{};
    }
    final result = <int, int>{};
    value.forEach((dynamic key, dynamic data) {
      final dimensionId = int.tryParse(key.toString());
      final score = data is num ? data.toInt() : int.tryParse('$data');
      if (dimensionId != null && score != null) {
        result[dimensionId] = score;
      }
    });
    return Map<int, int>.unmodifiable(result);
  }

  static int? _intFromJson(dynamic value) {
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

// 与后端播放列表分辨率筛选一致，按有效媒体的宽度划分 4K/8K 清晰度。
int _maxMediaWidthFromJson(dynamic value) {
  if (value is! List) return 0;
  var maxWidth = 0;
  for (final media in value) {
    if (media is! Map || media['valid'] == false) continue;
    final resolution = media['resolution'];
    if (resolution is! String) continue;
    final match = RegExp(r'^(\d+)x(\d+)$').firstMatch(resolution);
    if (match == null) continue;
    final width = int.tryParse(match[1]!);
    final height = int.tryParse(match[2]!);
    if (width != null &&
        width > 0 &&
        height != null &&
        height > 0 &&
        width > maxWidth) {
      maxWidth = width;
    }
  }
  return maxWidth;
}
