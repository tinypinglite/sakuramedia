import 'package:sakuramedia/core/json/json_parse.dart';

/// Provider-owned opaque source entry returned by `POST /import-sources/browse`.
enum ImportBrowseEntryType { file, directory }

ImportBrowseEntryType _parseEntryType(dynamic value) {
  return value == 'directory'
      ? ImportBrowseEntryType.directory
      : ImportBrowseEntryType.file;
}

Map<String, dynamic> _asObject(dynamic value) {
  if (value is! Map) {
    return const <String, dynamic>{};
  }
  return Map<String, dynamic>.unmodifiable(
    value.map((dynamic key, dynamic item) => MapEntry(key.toString(), item)),
  );
}

/// A single provider source. The host never interprets [sourceRef].
class ImportBrowseEntryDto {
  const ImportBrowseEntryDto({
    required this.sourceRef,
    required this.name,
    required this.entryType,
    required this.sizeBytes,
    required this.modifiedAt,
    required this.isVideo,
  });

  final Map<String, dynamic> sourceRef;
  final String name;
  final ImportBrowseEntryType entryType;
  final int? sizeBytes;
  final DateTime? modifiedAt;
  final bool isVideo;

  bool get isDirectory => entryType == ImportBrowseEntryType.directory;

  factory ImportBrowseEntryDto.fromJson(Map<String, dynamic> json) {
    return ImportBrowseEntryDto(
      sourceRef: _asObject(json['source_ref']),
      name: json['name'] as String? ?? '',
      entryType: _parseEntryType(json['entry_type']),
      sizeBytes: json['size_bytes'] == null ? null : asInt(json['size_bytes']),
      modifiedAt: asDateTime(json['modified_at']),
      isVideo: json['is_video'] as bool? ?? false,
    );
  }
}

/// Response returned by `POST /import-sources/browse`.
class ImportBrowseResponseDto {
  const ImportBrowseResponseDto({
    required this.libraryId,
    required this.entries,
    required this.nextCursor,
  });

  final int libraryId;
  final List<ImportBrowseEntryDto> entries;
  final String? nextCursor;

  factory ImportBrowseResponseDto.fromJson(Map<String, dynamic> json) {
    final rawEntries = json['entries'];
    final entries = rawEntries is List
        ? rawEntries
              .whereType<Map>()
              .map(
                (item) => ImportBrowseEntryDto.fromJson(
                  item.map(
                    (dynamic key, dynamic value) =>
                        MapEntry(key.toString(), value),
                  ),
                ),
              )
              .toList(growable: false)
        : const <ImportBrowseEntryDto>[];
    final nextCursor = json['next_cursor'];
    return ImportBrowseResponseDto(
      libraryId: asInt(json['library_id']),
      entries: entries,
      nextCursor: nextCursor is String && nextCursor.isNotEmpty
          ? nextCursor
          : null,
    );
  }
}
