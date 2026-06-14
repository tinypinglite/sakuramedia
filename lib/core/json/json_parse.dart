/// 统一的 JSON 字段解析助手。
///
/// 替代此前散落在各 DTO 内部、重复定义的 `_toInt` / `_tryInt` / `_parseDateTime`
/// / `_toMap` / `_stringOrNull` 等私有函数。后端字段类型偶有漂移（数字以字符串
/// 下发、空串当 null 等），这里集中做宽松解析，避免每个 DTO 各写一份。
library;

/// 宽松转 `int`：接受 `int` / `num` / 数字字符串；无法解析时返回 [fallback]（默认 0）。
int asInt(dynamic value, {int fallback = 0}) => asIntOrNull(value) ?? fallback;

/// 宽松转 `int?`：接受 `int` / `num` / 数字字符串；无法解析时返回 `null`。
int? asIntOrNull(dynamic value) {
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }
  if (value is String) {
    return int.tryParse(value);
  }
  return null;
}

/// 宽松转 `double?`：接受 `num` / 数字字符串；无法解析时返回 `null`。
double? asDoubleOrNull(dynamic value) {
  if (value is num) {
    return value.toDouble();
  }
  if (value is String) {
    return double.tryParse(value);
  }
  return null;
}

/// 解析 ISO-8601 时间字符串；非字符串或 trim 后为空时返回 `null`。
DateTime? asDateTime(dynamic value) {
  if (value is! String || value.trim().isEmpty) {
    return null;
  }
  return DateTime.tryParse(value);
}

/// 取字符串；非字符串返回 `null`。
///
/// [trim] 为 `true` 时先 trim，且 trim 后为空字符串也返回 `null`（等价于此前各处的
/// `_trimmedStringOrNull` / `_stringOrNull`）。
String? asStringOrNull(dynamic value, {bool trim = false}) {
  if (value is! String) {
    return null;
  }
  if (!trim) {
    return value;
  }
  final trimmed = value.trim();
  return trimmed.isEmpty ? null : trimmed;
}

/// 宽松转 `Map<String, dynamic>?`：非 Map 返回 `null`；键统一转为字符串。
Map<String, dynamic>? asMapOrNull(dynamic value) {
  if (value is Map<String, dynamic>) {
    return value;
  }
  if (value is Map) {
    return value.map(
      (dynamic key, dynamic v) => MapEntry(key.toString(), v),
    );
  }
  return null;
}

/// 同 [asMapOrNull]，但非 Map 时返回空 Map（用于「必有对象」字段的兜底）。
Map<String, dynamic> asMap(dynamic value) =>
    asMapOrNull(value) ?? <String, dynamic>{};
