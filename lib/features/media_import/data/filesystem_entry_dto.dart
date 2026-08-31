import 'package:sakuramedia/core/json/json_parse.dart';

/// 后端文件系统浏览条目类型。
enum FilesystemEntryType { dir, video, file }

FilesystemEntryType _parseEntryType(dynamic value) {
  switch (value) {
    case 'dir':
      return FilesystemEntryType.dir;
    case 'video':
      return FilesystemEntryType.video;
    default:
      return FilesystemEntryType.file;
  }
}

/// 单条文件系统条目（一层内的子目录或视频文件）。
class FilesystemEntryDto {
  const FilesystemEntryDto({
    required this.name,
    required this.path,
    required this.type,
    required this.size,
    required this.isVideo,
  });

  final String name;
  final String path;
  final FilesystemEntryType type;
  final int size;
  final bool isVideo;

  bool get isDirectory => type == FilesystemEntryType.dir;

  factory FilesystemEntryDto.fromJson(Map<String, dynamic> json) {
    return FilesystemEntryDto(
      name: json['name'] as String? ?? '',
      path: json['path'] as String? ?? '',
      type: _parseEntryType(json['type']),
      size: asInt(json['size']),
      isVideo: json['is_video'] as bool? ?? false,
    );
  }
}

/// `GET /filesystem/entries` 响应。
///
/// - [path] 为空字符串时表示多白名单根概览，[entries] 即各根目录条目。
/// - [parent] 为 `null` 表示已到白名单根，无法继续上翻。
class FilesystemListResponseDto {
  const FilesystemListResponseDto({
    required this.path,
    required this.parent,
    required this.entries,
  });

  final String path;
  final String? parent;
  final List<FilesystemEntryDto> entries;

  bool get isRootsOverview => path.isEmpty;

  factory FilesystemListResponseDto.fromJson(Map<String, dynamic> json) {
    final rawEntries = json['entries'];
    final entries =
        rawEntries is List
            ? rawEntries
                .whereType<Map>()
                .map(
                  (item) => FilesystemEntryDto.fromJson(
                    item.map(
                      (dynamic key, dynamic value) =>
                          MapEntry(key.toString(), value),
                    ),
                  ),
                )
                .toList(growable: false)
            : const <FilesystemEntryDto>[];

    final parent = json['parent'];
    return FilesystemListResponseDto(
      path: json['path'] as String? ?? '',
      parent: parent is String && parent.isNotEmpty ? parent : null,
      entries: entries,
    );
  }
}
