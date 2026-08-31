import 'package:sakuramedia/core/json/json_parse.dart';

/// `GET /download-tasks/{task_id}/files` 返回的单个文件条目（qB / 115 统一结构）。
class DownloadTaskFileDto {
  const DownloadTaskFileDto({
    required this.name,
    required this.size,
    this.isDir = false,
    this.path,
  });

  final String name;
  final int size;

  /// 115 目录条目用 `is_dir` 区分；qB 的文件列表恒为 false。
  final bool isDir;

  /// 115 相对任务目录的路径；qB 任务为 null（name 即种子内路径）。
  final String? path;

  factory DownloadTaskFileDto.fromJson(Map<String, dynamic> json) {
    return DownloadTaskFileDto(
      name: asStringOrNull(json['name']) ?? '',
      size: asInt(json['size']),
      isDir: json['is_dir'] as bool? ?? false,
      path: asStringOrNull(json['path'], trim: true),
    );
  }
}

/// `GET /download-tasks/{task_id}/files` 响应。
class DownloadTaskFilesDto {
  const DownloadTaskFilesDto({
    required this.taskId,
    required this.clientKind,
    this.files = const <DownloadTaskFileDto>[],
  });

  final int taskId;
  final String clientKind;
  final List<DownloadTaskFileDto> files;

  factory DownloadTaskFilesDto.fromJson(Map<String, dynamic> json) {
    final rawFiles = json['files'];
    return DownloadTaskFilesDto(
      taskId: asInt(json['task_id']),
      clientKind: asStringOrNull(json['client_kind']) ?? '',
      files: rawFiles is List
          ? rawFiles
                .whereType<Map>()
                .map(
                  (item) => DownloadTaskFileDto.fromJson(
                    item.map(
                      (dynamic key, dynamic value) =>
                          MapEntry(key.toString(), value),
                    ),
                  ),
                )
                .toList(growable: false)
          : const <DownloadTaskFileDto>[],
    );
  }
}
