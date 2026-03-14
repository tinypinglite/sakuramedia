import 'package:sakuramedia/features/movies/data/movie_list_item_dto.dart';
import 'package:sakuramedia/features/search/data/catalog_search_stream_stats.dart';

class MovieSearchStreamUpdate {
  const MovieSearchStreamUpdate({
    required this.stage,
    required this.message,
    this.current,
    this.total,
    this.results = const <MovieListItemDto>[],
    this.success,
    this.reason,
    this.stats,
  });

  final String stage;
  final String message;
  final int? current;
  final int? total;
  final List<MovieListItemDto> results;
  final bool? success;
  final String? reason;
  final CatalogSearchStreamStats? stats;

  bool get isComplete => stage == 'completed';
}
