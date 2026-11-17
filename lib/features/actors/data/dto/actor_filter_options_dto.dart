import 'package:json_annotation/json_annotation.dart';
import 'package:sakuramedia/core/json/dto_json_codec.dart';
import 'package:sakuramedia/core/json/json_parse.dart';

part 'actor_filter_options_dto.g.dart';

@JsonSerializable(converters: dtoJsonConverters, createToJson: false)
class ActorFilterRangeDto {
  const ActorFilterRangeDto({
    required this.min,
    required this.max,
    required this.populatedCount,
  });

  final int? min;
  final int? max;
  final int populatedCount;

  bool get hasValues => min != null && max != null;

  factory ActorFilterRangeDto.fromJson(Map<String, dynamic> json) =>
      _$ActorFilterRangeDtoFromJson(json);
}

@JsonSerializable(converters: dtoJsonConverters, createToJson: false)
class ActorCupFilterOptionDto {
  const ActorCupFilterOptionDto({required this.value, required this.count});

  @JsonKey(fromJson: _trimmedString)
  final String value;
  final int count;

  factory ActorCupFilterOptionDto.fromJson(Map<String, dynamic> json) =>
      _$ActorCupFilterOptionDtoFromJson(json);
}

@JsonSerializable(converters: dtoJsonConverters, createToJson: false)
class ActorFilterOptionsDto {
  const ActorFilterOptionsDto({
    required this.age,
    required this.heightCm,
    required this.cups,
  });

  @JsonKey(fromJson: _rangeFromJson)
  final ActorFilterRangeDto age;

  @JsonKey(fromJson: _rangeFromJson)
  final ActorFilterRangeDto heightCm;

  @JsonKey(fromJson: _cupsFromJson)
  final List<ActorCupFilterOptionDto> cups;

  factory ActorFilterOptionsDto.fromJson(Map<String, dynamic> json) =>
      _$ActorFilterOptionsDtoFromJson(json);
}

String _trimmedString(Object? value) => asStringOrNull(value, trim: true) ?? '';

ActorFilterRangeDto _rangeFromJson(Object? value) =>
    ActorFilterRangeDto.fromJson(asMap(value));

List<ActorCupFilterOptionDto> _cupsFromJson(Object? value) => asObjectList(
  value,
  ActorCupFilterOptionDto.fromJson,
).where((option) => option.value.isNotEmpty).toList(growable: false);
