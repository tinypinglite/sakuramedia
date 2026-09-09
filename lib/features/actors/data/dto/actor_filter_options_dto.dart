import 'package:sakuramedia/core/json/json_parse.dart';

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

  factory ActorFilterRangeDto.fromJson(Map<String, dynamic> json) {
    return ActorFilterRangeDto(
      min: asIntOrNull(json['min']),
      max: asIntOrNull(json['max']),
      populatedCount: asIntOrNull(json['populated_count']) ?? 0,
    );
  }
}

class ActorCupFilterOptionDto {
  const ActorCupFilterOptionDto({required this.value, required this.count});

  final String value;
  final int count;

  factory ActorCupFilterOptionDto.fromJson(Map<String, dynamic> json) {
    return ActorCupFilterOptionDto(
      value: asStringOrNull(json['value'], trim: true) ?? '',
      count: asIntOrNull(json['count']) ?? 0,
    );
  }
}

class ActorFilterOptionsDto {
  const ActorFilterOptionsDto({
    required this.age,
    required this.heightCm,
    required this.cups,
  });

  final ActorFilterRangeDto age;
  final ActorFilterRangeDto heightCm;
  final List<ActorCupFilterOptionDto> cups;

  factory ActorFilterOptionsDto.fromJson(Map<String, dynamic> json) {
    return ActorFilterOptionsDto(
      age: ActorFilterRangeDto.fromJson(_map(json['age'])),
      heightCm: ActorFilterRangeDto.fromJson(_map(json['height_cm'])),
      cups: _list(json['cups'])
          .map(ActorCupFilterOptionDto.fromJson)
          .where((option) => option.value.isNotEmpty)
          .toList(growable: false),
    );
  }

  static Map<String, dynamic> _map(Object? value) {
    if (value is Map<String, dynamic>) {
      return value;
    }
    if (value is Map) {
      return value.map(
        (dynamic key, dynamic item) => MapEntry(key.toString(), item),
      );
    }
    return const <String, dynamic>{};
  }

  static List<Map<String, dynamic>> _list(Object? value) {
    if (value is! List) {
      return const <Map<String, dynamic>>[];
    }
    return value.map(_map).toList(growable: false);
  }
}
