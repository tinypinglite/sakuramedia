import 'package:flutter/foundation.dart';
import 'package:sakuramedia/features/movies/data/dto/detail/movie_collection_type_dto.dart';

/// 一次跨页合集类型变更事件的载荷。
@immutable
class MovieCollectionTypeChange {
  const MovieCollectionTypeChange({
    required this.movieNumber,
    required this.targetType,
  });

  final String movieNumber;
  final MovieCollectionType targetType;
}
