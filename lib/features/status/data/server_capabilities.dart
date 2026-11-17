class ServerCapabilities {
  const ServerCapabilities({this.imageSearch = true, this.movieSimilarity = true});

  final bool imageSearch;
  final bool movieSimilarity;

  factory ServerCapabilities.fromJson(Map<String, dynamic> json) => ServerCapabilities(
    imageSearch: json['image_search'] as bool? ?? true,
    movieSimilarity: json['movie_similarity'] as bool? ?? true,
  );
}
