enum MovieCollectionType { collection, single }

extension MovieCollectionTypeApiValue on MovieCollectionType {
  String get apiValue {
    switch (this) {
      case MovieCollectionType.collection:
        return 'collection';
      case MovieCollectionType.single:
        return 'single';
    }
  }
}

class MovieCollectionStatusDto {
  const MovieCollectionStatusDto({
    required this.movieNumber,
    required this.isCollection,
  });

  final String movieNumber;
  final bool isCollection;

  factory MovieCollectionStatusDto.fromJson(Map<String, dynamic> json) {
    return MovieCollectionStatusDto(
      movieNumber: json['movie_number'] as String? ?? '',
      isCollection: json['is_collection'] as bool? ?? false,
    );
  }
}

class UpdateMovieCollectionTypePayload {
  const UpdateMovieCollectionTypePayload({
    required this.movieNumbers,
    required this.collectionType,
  });

  final List<String> movieNumbers;
  final MovieCollectionType collectionType;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'movie_numbers': movieNumbers,
      'collection_type': collectionType.apiValue,
    };
  }
}

class UpdateMovieCollectionTypeResultDto {
  const UpdateMovieCollectionTypeResultDto({
    required this.requestedCount,
    required this.updatedCount,
  });

  final int requestedCount;
  final int updatedCount;

  factory UpdateMovieCollectionTypeResultDto.fromJson(
    Map<String, dynamic> json,
  ) {
    return UpdateMovieCollectionTypeResultDto(
      requestedCount: json['requested_count'] as int? ?? 0,
      updatedCount: json['updated_count'] as int? ?? 0,
    );
  }
}
