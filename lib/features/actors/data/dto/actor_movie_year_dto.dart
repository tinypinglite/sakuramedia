import 'package:json_annotation/json_annotation.dart';
import 'package:sakuramedia/core/json/dto_json_codec.dart';

part 'actor_movie_year_dto.g.dart';

@JsonSerializable(converters: dtoJsonConverters, createToJson: false)
class ActorMovieYearDto {
  const ActorMovieYearDto({required this.year, required this.movieCount});

  final int year;
  final int movieCount;

  factory ActorMovieYearDto.fromJson(Map<String, dynamic> json) =>
      _$ActorMovieYearDtoFromJson(json);
}
