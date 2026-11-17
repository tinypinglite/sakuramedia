import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:sakuramedia/features/movies/data/dto/player/movie_subtitle_dto.dart';
import 'package:sakuramedia/features/movies/presentation/providers/movies_api_provider.dart';

part 'movie_subtitles_provider.g.dart';

@riverpod
Future<MovieSubtitleListDto> movieSubtitles(Ref ref, String movieNumber) {
  return ref
      .watch(moviesApiProvider)
      .getMovieSubtitles(movieNumber: movieNumber);
}
