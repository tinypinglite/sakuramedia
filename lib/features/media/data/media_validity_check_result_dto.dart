import 'package:sakuramedia/core/json/json_parse.dart';

class MediaValidityCheckResultDto {
  const MediaValidityCheckResultDto({
    required this.id,
    required this.path,
    required this.fileExists,
    required this.validBefore,
    required this.validAfter,
    required this.updated,
    required this.invalidated,
    required this.revived,
    required this.checkedAt,
  });

  final int id;
  final String path;
  final bool fileExists;
  final bool validBefore;
  final bool validAfter;
  final bool updated;
  final bool invalidated;
  final bool revived;
  final DateTime? checkedAt;

  factory MediaValidityCheckResultDto.fromJson(Map<String, dynamic> json) {
    return MediaValidityCheckResultDto(
      id: asInt(json['id']),
      path: json['path'] as String? ?? '',
      fileExists: json['file_exists'] as bool? ?? false,
      validBefore: json['valid_before'] as bool? ?? false,
      validAfter: json['valid_after'] as bool? ?? false,
      updated: json['updated'] as bool? ?? false,
      invalidated: json['invalidated'] as bool? ?? false,
      revived: json['revived'] as bool? ?? false,
      checkedAt: asDateTime(json['checked_at']),
    );
  }
}
