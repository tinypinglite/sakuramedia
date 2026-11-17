import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:sakuramedia/core/json/dto_json_codec.dart';
import 'package:sakuramedia/core/json/json_parse.dart';
import 'package:sakuramedia/features/movies/data/dto/listing/movie_list_item_dto.dart';

part 'actor_list_item_dto.g.dart';

@JsonSerializable(converters: dtoJsonConverters, createToJson: false)
@CopyWith()
class ActorListItemDto {
  const ActorListItemDto({
    required this.id,
    required this.name,
    required this.aliasName,
    required this.profileImage,
    required this.isSubscribed,
    this.apiDisplayName,
    this.movieCount = 0,
    this.age,
    this.birthday,
    this.heightCm,
    this.bustCm,
    this.waistCm,
    this.hipsCm,
    this.cup,
  });

  final int id;
  final String name;
  final String aliasName;
  @JsonKey(fromJson: movieImageFromJson)
  final MovieImageDto? profileImage;
  final bool isSubscribed;
  @JsonKey(name: 'display_name')
  final String? apiDisplayName;
  final int movieCount;
  final int? age;
  final DateTime? birthday;
  final int? heightCm;
  final int? bustCm;
  final int? waistCm;
  final int? hipsCm;
  @JsonKey(fromJson: _trimmedStringOrNull)
  final String? cup;

  String get displayName {
    final normalized = apiDisplayName?.trim();
    if (normalized != null && normalized.isNotEmpty) {
      return normalized;
    }
    return aliasName.trim().isNotEmpty ? aliasName : name;
  }

  _$ActorListItemDtoCWProxy get copyWith => _$ActorListItemDtoCWProxyImpl(this);

  factory ActorListItemDto.fromJson(Map<String, dynamic> json) =>
      _$ActorListItemDtoFromJson(json);
}

String? _trimmedStringOrNull(Object? value) =>
    asStringOrNull(value, trim: true);
