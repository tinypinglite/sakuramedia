import 'package:sakuramedia/core/json/json_parse.dart';

/// 单个元数据来源失败信息；reason 用于诊断，界面统一展示来源名。
class MetadataSourceErrorDto {
  const MetadataSourceErrorDto({
    required this.source,
    required this.sourceName,
    required this.reason,
    required this.detail,
  });

  final String source;
  final String sourceName;
  final String reason;
  final String detail;

  factory MetadataSourceErrorDto.fromJson(Map<String, dynamic> json) {
    return MetadataSourceErrorDto(
      source: json['source'] as String? ?? '',
      sourceName: json['source_name'] as String? ?? '',
      reason: json['reason'] as String? ?? '',
      detail: json['detail'] as String? ?? '',
    );
  }

  static List<MetadataSourceErrorDto> listFromJson(Object? value) {
    if (value is! List) return const <MetadataSourceErrorDto>[];
    return value
        .map((item) => MetadataSourceErrorDto.fromJson(asMap(item)))
        .toList(growable: false);
  }
}
