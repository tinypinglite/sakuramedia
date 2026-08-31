import 'package:sakuramedia/core/json/json_parse.dart';

class Cloud115DirectoryEntryDto {
  const Cloud115DirectoryEntryDto({
    required this.entryId,
    required this.name,
    required this.isDirectory,
    required this.size,
    required this.isVideo,
    required this.mtime,
  });

  final String entryId;
  final String name;
  final bool isDirectory;
  final int size;
  final bool isVideo;
  final int mtime;

  factory Cloud115DirectoryEntryDto.fromJson(Map<String, dynamic> json) {
    return Cloud115DirectoryEntryDto(
      entryId: json['entry_id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      isDirectory: json['is_dir'] as bool? ?? false,
      size: asInt(json['size']),
      isVideo: json['is_video'] as bool? ?? false,
      mtime: asInt(json['mtime']),
    );
  }
}

class Cloud115DirectoryPageDto {
  const Cloud115DirectoryPageDto({
    required this.cid,
    required this.total,
    required this.offset,
    required this.limit,
    required this.rootCid,
    required this.entries,
  });

  final String cid;
  final int total;
  final int offset;
  final int limit;
  final String rootCid;
  final List<Cloud115DirectoryEntryDto> entries;

  bool get hasMore => offset + entries.length < total;

  factory Cloud115DirectoryPageDto.fromJson(Map<String, dynamic> json) {
    final rawEntries = json['entries'];
    return Cloud115DirectoryPageDto(
      cid: json['cid'] as String? ?? '0',
      total: asInt(json['total']),
      offset: asInt(json['offset']),
      limit: asInt(json['limit']),
      rootCid: json['root_cid'] as String? ?? '',
      entries:
          rawEntries is List
              ? rawEntries
                  .whereType<Map>()
                  .map(
                    (item) => Cloud115DirectoryEntryDto.fromJson(
                      item.map(
                        (dynamic key, dynamic value) =>
                            MapEntry(key.toString(), value),
                      ),
                    ),
                  )
                  .toList(growable: false)
              : const <Cloud115DirectoryEntryDto>[],
    );
  }
}
