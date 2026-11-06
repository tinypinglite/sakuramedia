import 'package:json_annotation/json_annotation.dart';

import 'json_parse.dart';

/// 手写 DTO 共用的宽松 JSON 转换器。
///
/// 后端字段偶有 null / 数字字符串漂移；这些转换器把原有 `?? 0`、`asInt`
/// 等兜底语义集中到一处，避免每个字段重复标注。
const dtoJsonConverters = <JsonConverter>[
  IntJsonConverter(),
  NullableIntJsonConverter(),
  StringJsonConverter(),
  NullableStringJsonConverter(),
  BoolJsonConverter(),
  NullableBoolJsonConverter(),
  DoubleJsonConverter(),
  NullableDoubleJsonConverter(),
  DateTimeJsonConverter(),
  StringListJsonConverter(),
  StringMapJsonConverter(),
];

class IntJsonConverter extends JsonConverter<int, Object?> {
  const IntJsonConverter();

  @override
  int fromJson(Object? json) => asInt(json);

  @override
  Object? toJson(int object) => object;
}

class NullableIntJsonConverter extends JsonConverter<int?, Object?> {
  const NullableIntJsonConverter();

  @override
  int? fromJson(Object? json) => asIntOrNull(json);

  @override
  Object? toJson(int? object) => object;
}

class StringJsonConverter extends JsonConverter<String, Object?> {
  const StringJsonConverter();

  @override
  String fromJson(Object? json) => json as String? ?? '';

  @override
  Object? toJson(String object) => object;
}

class NullableStringJsonConverter extends JsonConverter<String?, Object?> {
  const NullableStringJsonConverter();

  @override
  String? fromJson(Object? json) => json as String?;

  @override
  Object? toJson(String? object) => object;
}

class BoolJsonConverter extends JsonConverter<bool, Object?> {
  const BoolJsonConverter();

  @override
  bool fromJson(Object? json) => json as bool? ?? false;

  @override
  Object? toJson(bool object) => object;
}

class NullableBoolJsonConverter extends JsonConverter<bool?, Object?> {
  const NullableBoolJsonConverter();

  @override
  bool? fromJson(Object? json) => json as bool?;

  @override
  Object? toJson(bool? object) => object;
}

class NullableDoubleJsonConverter extends JsonConverter<double?, Object?> {
  const NullableDoubleJsonConverter();

  @override
  double? fromJson(Object? json) => asDoubleOrNull(json);

  @override
  Object? toJson(double? object) => object;
}

class DoubleJsonConverter extends JsonConverter<double, Object?> {
  const DoubleJsonConverter();

  @override
  double fromJson(Object? json) => asDoubleOrNull(json) ?? 0;

  @override
  Object? toJson(double object) => object;
}

class DateTimeJsonConverter extends JsonConverter<DateTime?, Object?> {
  const DateTimeJsonConverter();

  @override
  DateTime? fromJson(Object? json) => asDateTime(json);

  @override
  Object? toJson(DateTime? object) => object?.toIso8601String();
}

class StringListJsonConverter extends JsonConverter<List<String>, Object?> {
  const StringListJsonConverter();

  @override
  List<String> fromJson(Object? json) => asStringList(json);

  @override
  Object? toJson(List<String> object) => object;
}

class StringMapJsonConverter
    extends JsonConverter<Map<String, String>, Object?> {
  const StringMapJsonConverter();

  @override
  Map<String, String> fromJson(Object? json) => asStringMap(json);

  @override
  Object? toJson(Map<String, String> object) => object;
}
