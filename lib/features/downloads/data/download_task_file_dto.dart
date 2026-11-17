import 'package:sakuramedia/core/json/json_parse.dart';

/// `GET /download-tasks/{task_id}/files` 返回的单个任务文件。
///
/// 后端只下发展示所需字段，provider 内部引用不出现在这里。
class DownloadTaskFileDto {
  const DownloadTaskFileDto({
    required this.name,
    required this.relativePath,
    required this.sizeBytes,
    required this.isVideo,
  });

  final String name;
  final String relativePath;
  final int sizeBytes;
  final bool isVideo;

  factory DownloadTaskFileDto.fromJson(Map<String, dynamic> json) {
    return DownloadTaskFileDto(
      name: json['name'] as String? ?? '',
      relativePath: json['relative_path'] as String? ?? '',
      sizeBytes: asInt(json['size_bytes']),
      isVideo: json['is_video'] as bool? ?? false,
    );
  }
}
