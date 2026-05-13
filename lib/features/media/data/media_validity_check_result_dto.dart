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
      id: _toInt(json['id']),
      path: json['path'] as String? ?? '',
      fileExists: json['file_exists'] as bool? ?? false,
      validBefore: json['valid_before'] as bool? ?? false,
      validAfter: json['valid_after'] as bool? ?? false,
      updated: json['updated'] as bool? ?? false,
      invalidated: json['invalidated'] as bool? ?? false,
      revived: json['revived'] as bool? ?? false,
      checkedAt: _parseDateTime(json['checked_at']),
    );
  }

  static DateTime? _parseDateTime(dynamic value) {
    if (value is! String || value.trim().isEmpty) {
      return null;
    }
    return DateTime.tryParse(value);
  }

  static int _toInt(dynamic value) {
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    if (value is String) {
      return int.tryParse(value) ?? 0;
    }
    return 0;
  }
}
