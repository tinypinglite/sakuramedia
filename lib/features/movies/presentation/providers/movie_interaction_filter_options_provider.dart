import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:sakuramedia/features/movies/data/dto/listing/movie_interaction_filter_options_dto.dart';
import 'package:sakuramedia/features/movies/presentation/providers/movies_api_provider.dart';

part 'movie_interaction_filter_options_provider.g.dart';

/// 互动数滑块上限跟随库内数据变化，面板每次打开时按需拉取，不做全局常驻缓存。
@riverpod
Future<MovieInteractionFilterOptionsDto> movieInteractionFilterOptions(
  Ref ref,
) {
  return ref.read(moviesApiProvider).getInteractionFilterOptions();
}
