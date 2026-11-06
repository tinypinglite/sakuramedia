// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'actor_filter_options_dto.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ActorFilterRangeDto _$ActorFilterRangeDtoFromJson(Map<String, dynamic> json) =>
    ActorFilterRangeDto(
      min: const NullableIntJsonConverter().fromJson(json['min']),
      max: const NullableIntJsonConverter().fromJson(json['max']),
      populatedCount: const IntJsonConverter().fromJson(
        json['populated_count'],
      ),
    );

ActorCupFilterOptionDto _$ActorCupFilterOptionDtoFromJson(
  Map<String, dynamic> json,
) => ActorCupFilterOptionDto(
  value: _trimmedString(json['value']),
  count: const IntJsonConverter().fromJson(json['count']),
);

ActorFilterOptionsDto _$ActorFilterOptionsDtoFromJson(
  Map<String, dynamic> json,
) => ActorFilterOptionsDto(
  age: _rangeFromJson(json['age']),
  heightCm: _rangeFromJson(json['height_cm']),
  cups: _cupsFromJson(json['cups']),
);
