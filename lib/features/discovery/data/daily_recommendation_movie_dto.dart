import 'package:sakuramedia/core/json/json_parse.dart';
import 'package:sakuramedia/features/movies/data/dto/listing/movie_list_item_dto.dart';

class DailyRecommendationMovieDto {
  const DailyRecommendationMovieDto({
    required this.movie,
    required this.snapshotDate,
    required this.generatedAt,
    required this.rank,
    required this.recommendationScore,
    required this.reasonCodes,
    required this.reasonTexts,
    required this.signalScores,
    required this.isStale,
  });

  final MovieListItemDto movie;
  final DateTime? snapshotDate;
  final DateTime? generatedAt;
  final int rank;
  final double recommendationScore;
  final List<String> reasonCodes;
  final List<String> reasonTexts;
  final Map<String, double> signalScores;
  final bool isStale;

  factory DailyRecommendationMovieDto.fromJson(Map<String, dynamic> json) {
    return DailyRecommendationMovieDto(
      movie: MovieListItemDto.fromJson(json),
      snapshotDate: _dateTimeFromJson(json['snapshot_date']),
      generatedAt: _dateTimeFromJson(json['generated_at']),
      rank: _intFromJson(json['rank']) ?? 0,
      recommendationScore: _doubleFromJson(json['recommendation_score']) ?? 0,
      reasonCodes: asStringList(json['reason_codes'], trim: true),
      reasonTexts: asStringList(json['reason_texts'], trim: true),
      signalScores: _signalScoresFromJson(json['signal_scores']),
      isStale: json['is_stale'] as bool? ?? false,
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

Map<String, double> _signalScoresFromJson(dynamic value) {
  if (value is! Map) {
    return const <String, double>{};
  }
  return value.map((dynamic key, dynamic data) {
    return MapEntry(key.toString(), _doubleFromJson(data) ?? 0);
  });
}
