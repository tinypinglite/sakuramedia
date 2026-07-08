import 'package:flutter/foundation.dart';
import 'package:sakuramedia/features/movies/data/movie_collection_type_dto.dart';

class MovieCollectionTypeChange {
  const MovieCollectionTypeChange({
    required this.movieNumber,
    required this.targetType,
  });

  final String movieNumber;
  final MovieCollectionType targetType;
}

class MovieCollectionTypeChangeNotifier extends ChangeNotifier {
  MovieCollectionTypeChange? _lastChange;
  MovieCollectionTypeChange? get lastChange => _lastChange;

  void reportChange({
    required String movieNumber,
    required MovieCollectionType targetType,
  }) {
    _lastChange = MovieCollectionTypeChange(
      movieNumber: movieNumber,
      targetType: targetType,
    );
    notifyListeners();
  }
}
